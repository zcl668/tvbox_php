#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
loveq.cn / love.cn 标签栏目爬虫（Termux 友好）
功能：
 - 爬取指定标签/栏目下的全部节目页面（自动翻页）
 - 从每个节目页提取媒体播放/下载链接（mp3/mp4/m3u8 等）
 - 支持两种模式：--mode links （只抓取并保存链接）或 --mode download（下载媒体文件）
 - 将已抓取记录保存在 SQLite 中，支持断点续抓
 - 并发抓取/下载（ThreadPoolExecutor）
 - 使用示例写在下面（必看）

使用前准备：
 pip install requests pyquery

Usage examples (在 Termux 或 Linux 下):
 1) 只抓取链接并保存到 links.csv:
    python3 loveq_spider.py \
      --start-url "https://www.loveq.cn/program-catX-p1.html" \
      --mode links \
      --out-dir /sdcard/Download/loveq_links

 2) 抓取并下载媒体到 /sdcard/Download/loveq_media，5 个并发：
    python3 loveq_spider.py \
      --start-url "https://www.loveq.cn/program-catX-p1.html" \
      --mode download \
      --out-dir /sdcard/Download/loveq_media \
      --workers 5

说明：
 - --start-url: 标签/栏目第一页 URL（脚本会尝试自动翻页）
 - --mode: links 或 download
 - --out-dir: 保存文件/数据库的根目录（默认 ./loveq_data）
 - --workers: 并发线程数（默认 4）
 - --rate: 每个线程请求之间的最小间隔（秒，默认 0.5）
"""

import os
import re
import sys
import time
import json
import argparse
import sqlite3
import threading
from urllib.parse import urljoin, urlparse
from concurrent.futures import ThreadPoolExecutor, as_completed
from typing import List, Optional, Tuple

import requests
from pyquery import PyQuery as pq

# -------------------- 配置 --------------------
HEADERS = {
    "User-Agent": "Mozilla/5.0 (Termux) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120 Safari/537.36"
}
REQUEST_TIMEOUT = 15  # seconds
DB_FILENAME = "loveq_spider.db"
# 支持的媒体后缀（用于直接正则抓取）
MEDIA_EXTS = [r"\.mp3\b", r"\.wma\b", r"\.mp4\b", r"\.m3u8\b", r"\.ts\b", r"\.aac\b", r"\.flv\b", r"\.ogg\b"]

# -------------------- 工具函数 --------------------
def safe_mkdir(path: str):
    os.makedirs(path, exist_ok=True)

def norm_url(base: str, link: str) -> str:
    return urljoin(base, link)

def is_media_url(url: str) -> bool:
    lower = url.split('?')[0].lower()
    for ext in MEDIA_EXTS:
        if re.search(ext, lower):
            return True
    return False

# 简单请求封装（重试）
def fetch_url(url: str, session: requests.Session, retries: int = 2) -> Optional[str]:
    for attempt in range(retries + 1):
        try:
            r = session.get(url, headers=HEADERS, timeout=REQUEST_TIMEOUT)
            if r.status_code == 200:
                r.encoding = r.apparent_encoding or r.encoding
                return r.text
            else:
                print(f"[WARN] {url} 返回 {r.status_code}")
        except Exception as e:
            print(f"[WARN] 请求 {url} 出错: {e}")
        time.sleep(1 + attempt * 1.0)
    return None

# 从页面中尽可能多地提取媒体链接
def extract_media_links(page_html: str, base_url: str) -> List[str]:
    results = set()
    doc = pq(page_html)
    # 1) 查找 audio/video 标签
    for a in doc("audio,video").items():
        src = a.attr("src")
        if src:
            results.add(norm_url(base_url, src))
        # 有时 <source> 在内部
        for s in a.find("source").items():
            ssrc = s.attr("src")
            if ssrc:
                results.add(norm_url(base_url, ssrc))
    # 2) 常见 JS 播放器配置（例如 var player = {...})
    text = page_html
    # 寻找 "file":"..." 或 "src":"..." 类型
    for m in re.finditer(r'["\'](?:file|src|url)["\']\s*:\s*["\']([^"\']+)["\']', text, re.IGNORECASE):
        results.add(norm_url(base_url, m.group(1)))
    # 3) 直接查找 http(s) 链接并过滤媒体后缀
    for m in re.finditer(r'https?://[^\'" >]+', text):
        u = m.group(0)
        if is_media_url(u):
            results.add(u)
    # 4) m3u8/ts 列表在页面以相对路径出现
    # 上面的 norm_url 会把相对路径拼好
    return sorted(results)

# 提取栏目页中的节目条目链接（根据常见列表结构）
def extract_episode_links(list_html: str, base_url: str) -> Tuple[List[str], Optional[str]]:
    doc = pq(list_html)
    links = []
    # 尝试常见结构：a[href*='program']、.list .item a、ul li a 等
    for sel in ["a[href*='program-']", "a[href*='program']",
                ".list a", ".post a", ".article-list a", ".item a", "li a"]:
        for a in doc(sel).items():
            href = a.attr("href")
            if not href:
                continue
            full = norm_url(base_url, href)
            # 过滤跳回栏目页或外链（保守筛选）
            if full.startswith(base_url) and ("/program" in full or "/program_" in full or "id=" in full or re.search(r'program.*\.html', full)):
                links.append(full)
    # 也保守地查找所有内部链接并按可能性筛选
    # 去重并保持顺序
    seen = set()
    filtered = []
    for u in links:
        if u not in seen:
            seen.add(u)
            filtered.append(u)
    # 翻页：尝试找到 "下一页" 或带页码的链接
    next_page = None
    # 常见 next 选择器
    for sel in ["a.next", "a:contains(下一页)", "a:contains(下页)", "a:contains(›)", "a:contains(»)", ".pagination a.next"]:
        el = doc(sel)
        if el and el.attr("href"):
            next_page = norm_url(base_url, el.attr("href"))
            break
    # 也尝试找到 page 数字链接并选出比当前更多的（不保证）
    return filtered, next_page

# SQLite 管理
class DB:
    def __init__(self, path):
        self.conn = sqlite3.connect(path, check_same_thread=False)
        self._lock = threading.Lock()
        self._ensure_tables()
    def _ensure_tables(self):
        with self.conn:
            self.conn.execute('''CREATE TABLE IF NOT EXISTS episodes (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                url TEXT UNIQUE,
                title TEXT,
                crawled INTEGER DEFAULT 0,
                timestamp DATETIME DEFAULT CURRENT_TIMESTAMP
            )''')
            self.conn.execute('''CREATE TABLE IF NOT EXISTS media (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                episode_url TEXT,
                media_url TEXT,
                filename TEXT,
                downloaded INTEGER DEFAULT 0,
                timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
                UNIQUE(episode_url, media_url)
            )''')
    def add_episode(self, url, title=None):
        with self._lock:
            try:
                self.conn.execute("INSERT OR IGNORE INTO episodes(url, title) VALUES (?,?)", (url, title))
                self.conn.commit()
            except Exception as e:
                print("DB add_episode error:", e)
    def mark_crawled(self, url):
        with self._lock:
            self.conn.execute("UPDATE episodes SET crawled=1 WHERE url=?", (url,))
            self.conn.commit()
    def list_uncrawled(self, limit=1000):
        cur = self.conn.execute("SELECT url FROM episodes WHERE crawled=0 LIMIT ?", (limit,))
        return [r[0] for r in cur.fetchall()]
    def add_media(self, episode_url, media_url, filename=None):
        with self._lock:
            try:
                self.conn.execute("INSERT OR IGNORE INTO media(episode_url, media_url, filename) VALUES (?,?,?)",
                                  (episode_url, media_url, filename))
                self.conn.commit()
            except Exception as e:
                print("DB add_media error:", e)
    def list_undownloaded_media(self, limit=1000):
        cur = self.conn.execute("SELECT episode_url, media_url, filename FROM media WHERE downloaded=0 LIMIT ?", (limit,))
        return cur.fetchall()
    def mark_media_downloaded(self, episode_url, media_url):
        with self._lock:
            self.conn.execute("UPDATE media SET downloaded=1 WHERE episode_url=? AND media_url=?", (episode_url, media_url))
            self.conn.commit()

# 下载文件（流式）
def download_media(media_url: str, dest_folder: str, session: requests.Session, rate: float = 0.5) -> Optional[str]:
    try:
        r = session.get(media_url, headers=HEADERS, stream=True, timeout=REQUEST_TIMEOUT)
        if r.status_code != 200:
            print(f"[WARN] 下载 {media_url} 返回 {r.status_code}")
            return None
        # 尝试从 URL 或响应头推断文件名
        filename = None
        cd = r.headers.get("content-disposition")
        if cd:
            m = re.search(r'filename\*?=(?:UTF-8\'\')?["\']?([^"\';]+)', cd)
            if m:
                filename = m.group(1)
        if not filename:
            filename = os.path.basename(urlparse(media_url).path) or f"media_{int(time.time())}"
        # 清理文件名
        filename = re.sub(r'[\\/*?:"<>|]', "_", filename)
        dest_path = os.path.join(dest_folder, filename)
        tmp_path = dest_path + ".part"
        with open(tmp_path, "wb") as f:
            for chunk in r.iter_content(chunk_size=8192):
                if chunk:
                    f.write(chunk)
        os.replace(tmp_path, dest_path)
        time.sleep(rate)
        return dest_path
    except Exception as e:
        print(f"[ERROR] 下载 {media_url} 出错: {e}")
        return None

# 主工作流程：爬取栏目页，收集所有节目链接
def crawl_list_pages(start_url: str, session: requests.Session, db: DB, rate: float = 0.5, max_pages: int = 1000):
    print("[*] 开始爬取栏目/标签页：", start_url)
    to_visit = [start_url]
    visited = set()
    pages = 0
    while to_visit and pages < max_pages:
        url = to_visit.pop(0)
        if url in visited:
            continue
        visited.add(url)
        print(f"[*] 获取栏目页：{url}")
        html = fetch_url(url, session)
        if not html:
            continue
        pages += 1
        base = "{uri.scheme}://{uri.netloc}".format(uri=urlparse(url))
        episodes, next_page = extract_episode_links(html, base)
        for ep in episodes:
            db.add_episode(ep)
        # 如果找到 next_page，则加入队列（且避免重复）
        if next_page and next_page not in visited and next_page not in to_visit:
            to_visit.append(next_page)
        # rate limit
        time.sleep(rate)

# 爬取单个 episode，提取 media links 并写入 DB / optional download
def process_episode(ep_url: str, session: requests.Session, db: DB, out_dir: str, mode: str = "links", rate: float = 0.5):
    print(f"[+] 处理节目：{ep_url}")
    html = fetch_url(ep_url, session)
    if not html:
        db.mark_crawled(ep_url)
        return
    media_links = extract_media_links(html, ep_url)
    title = None
    try:
        doc = pq(html)
        title = doc("title").text() or doc("h1").text()
    except:
        title = None
    # 存媒体记录
    for m in media_links:
        db.add_media(ep_url, m, filename=None)
    db.mark_crawled(ep_url)
    # 若为下载模式，则立即下载该 episode 的媒体（可另外安排下载队列）
    if mode == "download" and media_links:
        media_folder = os.path.join(out_dir, "media")
        safe_mkdir(media_folder)
        for m in media_links:
            # 先查看 DB 是否已下载
            # 下载并标记
            path = download_media(m, media_folder, session, rate)
            if path:
                print(f"[OK] 下载完成: {path}")
                db.mark_media_downloaded(ep_url, m)

# 主入口
def main():
    parser = argparse.ArgumentParser(description="loveq.cn 栏目爬虫 (links / download)")
    parser.add_argument("--start-url", required=True, help="栏目/标签第一页 URL")
    parser.add_argument("--out-dir", default="./loveq_data", help="保存目录")
    parser.add_argument("--mode", choices=["links", "download"], default="links", help="links: 只抓链接; download: 抓链接并下载")
    parser.add_argument("--workers", type=int, default=4, help="并发线程数")
    parser.add_argument("--rate", type=float, default=0.5, help="每次请求后的最小等待时间（秒）")
    args = parser.parse_args()

    safe_mkdir(args.out_dir)
    db_path = os.path.join(args.out_dir, DB_FILENAME)
    db = DB(db_path)
    session = requests.Session()

    # 1) 爬栏目页，收集 episode 列表
    crawl_list_pages(args.start_url, session, db, rate=args.rate)

    # 2) 并发处理未爬取的 episode（提取媒体链接并写 DB / 可选下载）
    to_process = db.list_uncrawled(limit=10000)
    print(f"[*] 待处理节目数: {len(to_process)}")
    if not to_process:
        print("[*] 无待处理节目，退出")
        return

    with ThreadPoolExecutor(max_workers=args.workers) as exe:
        futures = []
        for ep in to_process:
            futures.append(exe.submit(process_episode, ep, session, db, args.out_dir, args.mode, args.rate))
        for fut in as_completed(futures):
            try:
                fut.result()
            except Exception as e:
                print("[ERROR] 处理线程异常:", e)

    # 3) 如果是 links 模式，导出所有 media 链接到 CSV
    if args.mode == "links":
        out_csv = os.path.join(args.out_dir, "loveq_links.csv")
        print("[*] 导出链接到", out_csv)
        with open(out_csv, "w", encoding="utf-8") as f:
            f.write("episode_url,media_url,filename,downloaded\n")
            c = db.conn.execute("SELECT episode_url, media_url, filename, downloaded FROM media")
            for row in c.fetchall():
                f.write(",".join(['"'+(row[0] or '')+'"', '"'+(row[1] or '')+'"', '"'+(row[2] or '')+'"', str(row[3])]) + "\n")
        print("[*] 完成")

if __name__ == "__main__":
    main()