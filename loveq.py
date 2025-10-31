#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
loveq.cn 音频下载工具 - 优化多线程版
支持单日/年份/全站抓取
支持 MP3/WMA 音频和 RAR 文件
按年份分组保存 txt
"""
import os
import re
import time
import requests
import threading
from concurrent.futures import ThreadPoolExecutor, as_completed
from bs4 import BeautifulSoup
from urllib.parse import urljoin
from datetime import datetime

BASE_URL = "https://www.loveq.cn"
HEADERS = {
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
    "Referer": "https://www.loveq.cn/",
}
DOWNLOAD_FOLDER = "audio"  # 下载文件夹

# 线程控制
MAX_WORKERS_SINGLE = 50  # 单日/年份模式
MAX_WORKERS_FULL = 20     # 全站模式
thread_lock = threading.Lock()

session = requests.Session()
session.headers.update(HEADERS)

# --------------------- 基础请求和解析 ---------------------
def get_page(url):
    try:
        r = session.get(url, timeout=15)
        r.encoding = 'utf-8'
        return r.text if r.status_code == 200 else ""
    except Exception as e:
        print(f"❌ 请求失败: {url} - {e}")
        return ""

def get_all_categories():
    """获取栏目列表"""
    print("🔍 获取栏目列表...")
    html = get_page(f"{BASE_URL}/program.html")
    if not html:
        return []

    soup = BeautifulSoup(html, "lxml")
    categories = []
    category_links = soup.find_all("a", href=re.compile(r'program-cat\d+-p1\.html'))

    for a in category_links:
        href = a.get("href", "")
        title = a.get_text(strip=True)
        if title and "program-cat" in href:
            match = re.search(r'program-cat(\d+)-p1\.html', href)
            if match:
                cat_id = match.group(1)
                categories.append({"id": cat_id, "title": title, "url": urljoin(BASE_URL, href)})

    categories.sort(key=lambda x: int(x['id']))
    filtered_categories = [cat for cat in categories if cat['id'] != '0']

    print(f"✅ 找到 {len(categories)} 个栏目，过滤后剩余 {len(filtered_categories)} 个")
    return filtered_categories

def get_programs_from_category(cat_id, category_title, max_pages=100, year=None):
    programs = []
    for page in range(1, max_pages + 1):
        url = f"{BASE_URL}/program-cat{cat_id}-p{page}.html" + (f"?year={year}" if year else "")
        html = get_page(url)
        if not html:
            break
        soup = BeautifulSoup(html, "lxml")
        program_links = soup.find_all("a", href=re.compile(r'program_download'))
        for a in program_links:
            href = a.get("href", "")
            title = a.get_text(strip=True)
            if title and "program_download" in href:
                full_url = urljoin(BASE_URL, href)
                if full_url not in [p["url"] for p in programs]:
                    programs.append({"title": title, "url": full_url, "category_id": cat_id, "category_title": category_title})
    return programs

# --------------------- 日期提取 ---------------------
def extract_date_from_title(title):
    patterns = [
        r'(\d{4}-\d{2}-\d{2})',
        r'(\d{4}\.\d{2}\.\d{2})',
        r'(\d{4}/\d{2}/\d{2})',
        r'(\d{4})年(\d{1,2})月(\d{1,2})日',
        r'(\d{4})\.(\d{1,2})\.(\d{1,2})',
    ]
    for pattern in patterns:
        match = re.search(pattern, title)
        if match:
            if len(match.groups()) == 1:
                return match.group(1).replace('.', '-').replace('/', '-')
            elif len(match.groups()) == 3:
                year, month, day = match.groups()
                return f"{year}-{month.zfill(2)}-{day.zfill(2)}"
    return None

def extract_year_from_title(title):
    match = re.search(r'(\d{4})', title)
    return match.group(1) if match else None

# --------------------- 节目内容与音频 ---------------------
def get_program_content(program_url):
    html = get_page(program_url)
    if not html:
        return ""
    soup = BeautifulSoup(html, "lxml")
    content_li = soup.find('li', string=re.compile('节目内容：'))
    if content_li:
        content_text = content_li.get_text(strip=True)
        if '：' in content_text:
            content = content_text.split('：', 1)[1]
            if content and content != "节目内容":
                return content.strip()
    # div/p选择器
    selectors = ['div.block2 ul.pdl1 li','div.program-content','div.content','p.content']
    for sel in selectors:
        elements = soup.select(sel)
        for e in elements:
            text = e.get_text(strip=True)
            if text and len(text)>10:
                return text.strip()
    meta_desc = soup.find('meta', attrs={'name':'description'})
    if meta_desc and meta_desc.get('content'):
        return meta_desc.get('content').strip()
    return ""

def get_audio_url_and_content(program_url, program_title):
    html = get_page(program_url)
    if not html:
        return None, "", None
    program_content = get_program_content(program_url)
    # 正则匹配真实音频或rar文件
    patterns = [
        r'https://dl2\.loveq\.cn:8090/live/program/\d+/\d+\.\d+\.\d+\.(mp3|wma)\?sign=[a-f0-9]+&timestamp=\d+',
        r'https://dl2\.loveq\.cn:8090/live/program/\d+/\d+\.\d+\.\d+\.rar\?sign=[a-f0-9]+&timestamp=\d+'
    ]
    for pattern in patterns:
        matches = re.findall(pattern, html, re.IGNORECASE)
        if matches:
            audio_url = matches[0]
            file_format = 'rar' if '.rar' in audio_url else ('wma' if '.wma' in audio_url else 'mp3')
            return audio_url, program_content, file_format
    # audio标签备选
    audio_pattern = r'<audio[^>]*src=["\']([^"\']+\.(?:mp3|wma|rar)[^"\']*)["\'][^>]*>'
    audio_matches = re.findall(audio_pattern, html, re.IGNORECASE)
    for audio_url in audio_matches:
        full_url = audio_url if audio_url.startswith('http') else urljoin(BASE_URL, audio_url)
        if "dl2.loveq.cn:8090" in full_url:
            file_format = 'rar' if '.rar' in full_url else ('wma' if '.wma' in full_url else 'mp3')
            return full_url, program_content, file_format
    return None, "", None

# --------------------- 下载 ---------------------
def download_audio(audio_url, filename, program_url=None):
    try:
        headers = HEADERS.copy()
        if program_url:
            headers["Referer"] = program_url
        r = session.get(audio_url, headers=headers, stream=True, timeout=30)
        if r.status_code == 200:
            with open(filename, "wb") as f:
                for chunk in r.iter_content(8192):
                    if chunk: f.write(chunk)
            return True
    except: pass
    return False

# --------------------- 格式化 ---------------------
def format_program_title(original_title, content, sequence_number=None):
    date = extract_date_from_title(original_title)
    formatted_date = date.replace('-','.') if date else original_title
    if sequence_number and sequence_number>1:
        formatted_date = f"{formatted_date}-{sequence_number}"
    clean_content = re.sub(r'\d{4}[\.\-/]\d{1,2}[\.\-/]\d{1,2}','', content.strip()) if content else ''
    return f"{formatted_date} {clean_content}" if clean_content else formatted_date

# --------------------- 多线程处理 ---------------------
def process_single_program(args):
    program, i, total, download_option = args
    audio_url, content, file_format = get_audio_url_and_content(program['url'], program['title'])
    result = None
    if audio_url:
        result = {'original_title': program['title'], 'audio_url': audio_url,
                  'content': content, 'url': program['url'], 'file_format': file_format,
                  'category_title': program.get('category_title','未知栏目')}
        if download_option=='y':
            ext = file_format if file_format else 'mp3'
            clean_title = re.sub(r'[<>:"/\\|?*]','_',program['title'])
            filename = os.path.join(DOWNLOAD_FOLDER, f"{clean_title}.{ext}")
            result['download_success'] = download_audio(audio_url, filename, program['url'])
    time.sleep(0.1)
    return result

def process_programs_multithread(programs, download_option, mode_name, categories):
    print(f"\n🎵 多线程处理 {len(programs)} 个节目...")
    entries=[]
    thread_count = MAX_WORKERS_FULL if "全站" in mode_name else MAX_WORKERS_SINGLE
    thread_args = [(program, i+1,len(programs),download_option) for i,program in enumerate(programs)]
    with ThreadPoolExecutor(max_workers=thread_count) as executor:
        futures = [executor.submit(process_single_program,arg) for arg in thread_args]
        for future in as_completed(futures):
            res = future.result()
            if res: entries.append(res)
    filename = f"loveq_{mode_name}.txt"
    save_results_by_year(entries, filename, mode_name, categories)

# --------------------- 保存 ---------------------
def save_results_by_year(entries, filename, mode_info, categories):
    if not entries: return
    with open(filename,"w",encoding="utf-8") as f:
        f.write(f"# loveq.cn 音频链接 - {mode_info}\n# 生成时间: {datetime.now()}\n# 格式: 日期 节目内容\n\n")
        for entry in entries:
            f.write(f"{format_program_title(entry['original_title'], entry['content'])},{entry['audio_url']}\n")
    print(f"✅ 已保存 {len(entries)} 条节目到 {filename}")

# --------------------- 抓取模式 ---------------------
def crawl_single_date(target_date, download_option, categories):
    target_programs=[]
    target_year = target_date.split('-')[0]
    for cat in categories:
        for page in range(1,16):
            url=f"{BASE_URL}/program-cat{cat['id']}-p{page}.html?year={target_year}"
            html=get_page(url)
            if not html: break
            soup = BeautifulSoup(html,"lxml")
            for a in soup.find_all("a",href=re.compile(r'program_download')):
                title=a.get_text(strip=True)
                if extract_date_from_title(title)==target_date:
                    full_url=urljoin(BASE_URL,a.get("href"))
                    target_programs.append({"title":title,"url":full_url,"category_id":cat['id'],"category_title":cat['title']})
    process_programs_multithread(target_programs, download_option, f"单日_{target_date}", categories)

def crawl_by_year(target_year, download_option, categories):
    all_programs=[]
    for cat in categories:
        all_programs.extend(get_programs_from_category(cat['id'],cat['title'],year=target_year))
    process_programs_multithread(all_programs, download_option, f"年份_{target_year}", categories)

def crawl_full_site(download_option, categories, max_pages_per_category=20):
    all_programs=[]
    for cat in categories:
        try:
            programs = get_programs_from_category(cat['id'],cat['title'],max_pages=max_pages_per_category)
            all_programs.extend(programs)
        except Exception as e:
            print(f"❌ {cat['title']} 抓取出错: {e}")
    process_programs_multithread(all_programs, download_option, "全站", categories)

# --------------------- 主程序 ---------------------
def main():
    if not os.path.exists(DOWNLOAD_FOLDER): os.makedirs(DOWNLOAD_FOLDER)
    categories=get_all_categories()
    if not categories: return
    print("选择抓取模式 1:单日 2:年份 3:全站")
    mode=input("请输入选择 (1/2/3): ").strip()
    download_option=input("是否下载音频文件？(y/N): ").strip().lower() or 'n