#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Termux 智能爬虫（抓取播放链接 + 网站框架 + 栏目结构）

使用示例：
-------------------------------
# 抓取自定义网站，匹配关键词“新闻 Python”
python3 termux_crawler_site.py https://example.com --keywords 新闻 Python

# 抓取多个网站
python3 termux_crawler_site.py https://example.com https://another.com --keywords AI 视频

说明：
-------------------------------
- 自动分析网站导航/分类/栏目
- 只抓取包含关键词的页面
- 收集页面中的播放链接（图片/视频/音频），不下载
- 保存结果到 SQLite 和 JSONL 文件
"""

import argparse
import logging
import os
import queue
import sqlite3
import json
import time
import threading
from urllib.parse import urljoin, urlparse, urldefrag
import requests
from bs4 import BeautifulSoup
from concurrent.futures import ThreadPoolExecutor
from requests.adapters import HTTPAdapter
from urllib3.util.retry import Retry
import urllib.robotparser as robotparser

# ========== 配置 ==========
DEFAULT_USER_AGENT = "TermuxCrawler/2.0 (+https://example.local)"
DEFAULT_WORKERS = 6
DEFAULT_DELAY = 1.0
DEFAULT_TIMEOUT = 15
DEFAULT_MAX_PAGES = 200
DEFAULT_MAX_DEPTH = 3
DB_FILENAME = "crawl_links.db"
JSONL_FILENAME = "crawl_links.jsonl"
CATEGORY_JSONL = "categories.jsonl"

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(threadName)s %(message)s"
)
logger = logging.getLogger("crawler")

# ========== 工具函数 ==========
def normalized_link(base, link):
    if not link:
        return None
    try:
        full = urljoin(base, link.strip())
        full, _ = urldefrag(full)
        return full
    except Exception:
        return None

def ensure_dir(path):
    if not os.path.exists(path):
        os.makedirs(path)

# ========== 数据库 ==========
def init_db(db_path):
    conn = sqlite3.connect(db_path, check_same_thread=False)
    cur = conn.cursor()
    # 页面表
    cur.execute("""CREATE TABLE IF NOT EXISTS pages (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    url TEXT UNIQUE,
                    status INTEGER,
                    title TEXT,
                    snippet TEXT,
                    media_links TEXT,
                    fetched_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                )""")
    # 栏目表
    cur.execute("""CREATE TABLE IF NOT EXISTS categories (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    name TEXT,
                    url TEXT,
                    parent_url TEXT,
                    fetched_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    UNIQUE(name, url)
                )""")
    conn.commit()
    return conn

def save_page_db(conn, url, status, title, snippet, media_links):
    try:
        cur = conn.cursor()
        cur.execute("""
            INSERT OR REPLACE INTO pages (url, status, title, snippet, media_links)
            VALUES (?, ?, ?, ?, ?)
        """, (url, status, title, snippet, json.dumps(media_links, ensure_ascii=False)))
        conn.commit()
    except Exception as e:
        logger.debug("DB save failed: %s", e)

def save_category(conn, name, url, parent_url=None):
    try:
        cur = conn.cursor()
        cur.execute("""
            INSERT OR IGNORE INTO categories (name, url, parent_url)
            VALUES (?, ?, ?)
        """, (name, url, parent_url))
        conn.commit()
        # 保存 JSONL
        with open(CATEGORY_JSONL, "a", encoding="utf-8") as f:
            f.write(json.dumps({
                "name": name,
                "url": url,
                "parent_url": parent_url,
                "fetched_at": time.strftime("%Y-%m-%d %H:%M:%S")
            }, ensure_ascii=False) + "\n")
    except Exception as e:
        logger.debug("Category save failed: %s", e)

# ========== Robots.txt ==========
def allowed_by_robots(url, user_agent, rp_cache):
    parsed = urlparse(url)
    root = f"{parsed.scheme}://{parsed.netloc}"
    if root not in rp_cache:
        rp = robotparser.RobotFileParser()
        robots_url = urljoin(root, "/robots.txt")
        try:
            rp.set_url(robots_url)
            rp.read()
        except Exception:
            rp = None
        rp_cache[root] = rp
    rp = rp_cache[root]
    if rp is None:
        return True
    return rp.can_fetch(user_agent, url)

# ========== Session ==========
def make_session(user_agent=None, proxies=None, timeout=DEFAULT_TIMEOUT):
    s = requests.Session()
    ua = user_agent or DEFAULT_USER_AGENT
    s.headers.update({"User-Agent": ua})
    if proxies:
        s.proxies.update(proxies)
    retries = Retry(total=3, backoff_factor=0.8, status_forcelist=(429,500,502,503,504))
    adapter = HTTPAdapter(max_retries=retries)
    s.mount("http://", adapter)
    s.mount("https://", adapter)
    return s

# ========== 爬虫类 ==========
class LinkCrawler:
    def __init__(self, start_urls, keywords,
                 max_pages=DEFAULT_MAX_PAGES,
                 max_depth=DEFAULT_MAX_DEPTH,
                 workers=DEFAULT_WORKERS,
                 delay=DEFAULT_DELAY,
                 user_agent=None,
                 proxies=None,
                 timeout=DEFAULT_TIMEOUT,
                 respect_robots=True,
                 out_db=DB_FILENAME,
                 out_jsonl=JSONL_FILENAME):

        self.start_urls = list(set(start_urls))
        self.keywords = [k.lower() for k in keywords if k.strip()]
        self.max_pages = max_pages
        self.max_depth = max_depth
        self.workers = workers
        self.delay = delay
        self.user_agent = user_agent or DEFAULT_USER_AGENT
        self.proxies = proxies
        self.timeout = timeout
        self.respect_robots = respect_robots
        self.out_db = out_db
        self.out_jsonl = out_jsonl

        self.visited = set()
        self.visited_lock = threading.Lock()
        self.to_fetch = queue.Queue()
        self.domain_last_time = {}
        self.domain_lock = threading.Lock()
        self.jsonl_lock = threading.Lock()
        self.rp_cache = {}

        self.session = make_session(user_agent=self.user_agent, proxies=self.proxies, timeout=self.timeout)
        self.db_conn = init_db(self.out_db)

        for u in self.start_urls:
            self.to_fetch.put((u, 0))

    def enforce_delay(self, url):
        host = urlparse(url).netloc
        now = time.time()
        with self.domain_lock:
            last = self.domain_last_time.get(host, 0)
            wait = self.delay - (now - last)
            if wait > 0:
                time.sleep(wait)
            self.domain_last_time[host] = time.time()

    def contains_keyword(self, text):
        if not text:
            return False
        lower = text.lower()
        return any(k in lower for k in self.keywords)

    def collect_media_links(self, soup, base_url):
        links = set()
        for tag in soup.find_all(["img","video","audio","source"]):
            src = tag.get("src")
            if src:
                link = normalized_link(base_url, src)
                if link:
                    links.add(link)
        return links

    def extract_categories(self, soup, base_url, parent_url=None):
        categories = []
        navs = soup.find_all(["nav","ul","li"])
        for nav in navs:
            for a in nav.find_all("a", href=True):
                name = a.get_text(strip=True)
                url = normalized_link(base_url, a.get("href"))
                if name and url:
                    categories.append({"name": name, "url": url, "parent_url": parent_url})
        return categories

    def process_page(self, url, depth):
        if self.respect_robots and not allowed_by_robots(url, self.user_agent, self.rp_cache):
            return

        with self.visited_lock:
            if url in self.visited or len(self.visited) >= self.max_pages:
                return
            self.visited.add(url)

        logger.info("Fetching (%d/%d) depth=%d: %s", len(self.visited), self.max_pages, depth, url)
        self.enforce_delay(url)
        try:
            r = self.session.get(url, timeout=self.timeout)
        except Exception:
            return

        if not r.ok or "text" not in r.headers.get("Content-Type",""):
            return

        try:
            r.encoding = r.apparent_encoding
            soup = BeautifulSoup(r.text, "html.parser")
            text = soup.get_text(" ", strip=True)
            title = soup.title.get_text(strip=True) if soup.title else ""
        except Exception:
            return

        # 抓取栏目
        categories = self.extract_categories(soup, url)
        for cat in categories:
            save_category(self.db_conn, cat["name"], cat["url"], cat.get("parent_url"))

        # 抓取播放链接
        if self.contains_keyword(text):
            media_links = self.collect_media_links(soup, url)
            snippet = text[:300].replace("\n"," ")
            save_page_db(self.db_conn, url, r.status_code, title, snippet, media_links)
            with self.jsonl_lock:
                with open(self.out_jsonl, "a", encoding="utf-8") as f:
                    f.write(json.dumps({
                        "url": url,
                        "status": r.status_code,
                        "title": title,
                        "snippet": snippet,
                        "media_links": list(media_links),
                        "fetched_at": time.strftime("%Y-%m-%d %H:%M:%S")
                    }, ensure_ascii=False) + "\n")

        # 下一层
        if depth+1 <= self.max_depth:
            for tag in soup.find_all("a", href=True):
                link = normalized_link(url, tag.get("href"))
                if link and urlparse(link).scheme in ("http","https"):
                    with self.visited_lock:
                        if link not in self.visited:
                            self.to_fetch.put((link, depth+1))

    def worker(self):
        while True:
            try:
                url, depth = self.to_fetch.get(timeout=2)
            except Exception:
                break
            try:
                self.process_page(url, depth)
            except Exception:
                logger.exception("Worker error on %s", url)
            finally:
                self.to_fetch.task_done()
            with self.visited_lock:
                if len(self.visited) >= self.max_pages:
                    break

    def run(self):
        logger.info("Start crawl: %d URLs, keywords=%s", len(self.start_urls), self.keywords)
        if not os.path.exists(self.out_jsonl):
            open(self.out_jsonl, "w", encoding="utf-8").close()
        if not os.path.exists(CATEGORY_JSONL):
            open(CATEGORY_JSONL, "w", encoding="utf-8").close()

        with ThreadPoolExecutor(max_workers=self.workers) as exe:
            for _ in range(self.workers):
                exe.submit(self.worker)

            while True:
                time.sleep(0.5)
                with self.visited_lock:
                    if len(self.visited) >= self.max_pages:
                        break
                if self.to_fetch.empty():
                    break

        logger.info("Crawl finished, total visited: %d", len(self.visited))
        self.db_conn.close()

# ========== CLI ==========
def parse_args():
    p = argparse.ArgumentParser(description="Termux 智能爬虫（抓取播放链接 + 网站结构 + 分类）")
    p.add_argument("start", nargs="+", help="起始 URL")
    p.add_argument("--keywords", nargs="+", required=True, help="关键词（至少一个）")
    p.add_argument("--max-pages", type=int, default=DEFAULT_MAX_PAGES)
    p.add_argument("--max-depth", type=int, default=DEFAULT_MAX_DEPTH)
    p.add_argument("--workers", type=int, default=DEFAULT_WORKERS)
    p.add_argument("--delay", type=float, default=DEFAULT_DELAY)
    p.add_argument("--user-agent", default=DEFAULT_USER_AGENT)
    p.add_argument("--ignore-robots", action="store_true")
    p.add_argument("--proxy", help="HTTP 代理，例如 http://127.0.0.1:8080")
    p.add_argument("--timeout", type=int, default=DEFAULT_TIMEOUT)
    p.add_argument("--db", default=DB_FILENAME)
    p.add_argument("--jsonl", default=JSONL_FILENAME)
    return p.parse_args()

def main():
    args = parse_args()
    proxies = None
    if args.proxy:
        proxies = {"http": args.proxy, "https": args.proxy}

    crawler = LinkCrawler(
        start_urls=args.start,
        keywords=args.keywords,
        max_pages=args.max_pages,
        max_depth=args.max_depth,
        workers=args.workers,
        delay=args.delay,
        user_agent=args.user_agent,
        proxies=proxies,
        timeout=args.timeout,
        respect_robots=not args.ignore_robots,
        out_db=args.db,
        out_jsonl=args.jsonl
    )
    crawler.run()

if __name__ == "__main__":
    main()