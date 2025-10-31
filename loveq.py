#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
loveq.cn 音频下载 - 支持单日/年份/全站抓取（包含节目内容）
线程数已优化为 50（华为 P40 Pro 适合 I/O 密集型下载）
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
DOWNLOAD_FOLDER = "audio"  # 文件保存目录

# 线程控制
MAX_WORKERS = 50  # 华为 P40 Pro I/O 密集型下载可用
thread_lock = threading.Lock()

session = requests.Session()
session.headers.update(HEADERS)

# --------------------- 基础请求与栏目获取 ---------------------
def get_page(url):
    try:
        r = session.get(url, timeout=15)
        r.encoding = 'utf-8'
        return r.text if r.status_code == 200 else ""
    except Exception as e:
        print(f"❌ 请求失败: {url} - {e}")
        return ""

def get_all_categories():
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
                categories.append({
                    "id": cat_id,
                    "title": title,
                    "url": urljoin(BASE_URL, href)
                })

    categories.sort(key=lambda x: int(x['id']))
    filtered_categories = [cat for cat in categories if cat['id'] != '0']
    return filtered_categories

# --------------------- 节目列表获取 ---------------------
def get_programs_from_category(cat_id, category_title, max_pages=100, year=None):
    programs = []
    for page in range(1, max_pages + 1):
        url = f"{BASE_URL}/program-cat{cat_id}-p{page}.html" + (f"?year={year}" if year else "")
        html = get_page(url)
        if not html: break

        soup = BeautifulSoup(html, "lxml")
        program_links = soup.find_all("a", href=re.compile(r'program_download'))

        found_programs = False
        for a in program_links:
            href = a.get("href", "")
            title = a.get_text(strip=True)
            if title and "program_download" in href:
                full_url = urljoin(BASE_URL, href)
                if full_url not in [p["url"] for p in programs]:
                    programs.append({
                        "title": title,
                        "url": full_url,
                        "category_id": cat_id,
                        "category_title": category_title
                    })
                    found_programs = True
        if not found_programs: break
        time.sleep(0.3)
    return programs

# --------------------- 节目内容解析 ---------------------
def extract_date_from_title(title):
    patterns = [r'(\d{4}-\d{2}-\d{2})', r'(\d{4}\.\d{2}\.\d{2})', r'(\d{4}/\d{2}/\d{2})',
                r'(\d{4})年(\d{1,2})月(\d{1,2})日', r'(\d{4})\.(\d{1,2})\.(\d{1,2})']
    for pattern in patterns:
        match = re.search(pattern, title)
        if match:
            if len(match.groups()) == 1:
                return match.group(1).replace('.', '-').replace('/', '-')
            elif len(match.groups()) == 3:
                y, m, d = match.groups()
                return f"{y}-{m.zfill(2)}-{d.zfill(2)}"
    return None

def extract_year_from_title(title):
    match = re.search(r'(\d{4})', title)
    return match.group(1) if match else None

def get_program_content(program_url):
    html = get_page(program_url)
    if not html: return ""
    soup = BeautifulSoup(html, "lxml")

    content_li = soup.find('li', string=re.compile('节目内容：'))
    if content_li:
        text = content_li.get_text(strip=True)
        return text.split('：', 1)[1].strip() if '：' in text else text.strip()

    for selector in ['div.block2 ul.pdl1 li','div.program-content','div.content','p.content']:
        for element in soup.select(selector):
            text = element.get_text(strip=True)
            if text and len(text) > 10 and '节目' not in text and '下载' not in text:
                return text.strip()

    meta_desc = soup.find('meta', attrs={'name': 'description'})
    if meta_desc and meta_desc.get('content') and len(meta_desc.get('content'))>20:
        return meta_desc.get('content').strip()
    return ""

# --------------------- 音频链接解析 ---------------------
def get_audio_url_and_content(program_url, program_title):
    html = get_page(program_url)
    if not html: return None, "", None
    program_content = get_program_content(program_url)

    patterns = [
        # MP3
        r'https://dl2\.loveq\.cn:8090/live/program/\d+/\d+\.\d+\.\d+\.mp3\?sign=[a-f0-9]+&timestamp=\d+',
        r'https://dl2\.loveq\.cn:8090/live/program/\d+/\d+-\d+-\d+_[^\.]+\.mp3\?sign=[a-f0-9]+&timestamp=\d+',
        # WMA
        r'https://dl2\.loveq\.cn:8090/live/program/\d+/\d+\.\d+\.\d+\.wma\?sign=[a-f0-9]+&timestamp=\d+',
        r'https://dl2\.loveq\.cn:8090/live/program/\d+/\d+-\d+-\d+_[^\.]+\.wma\?sign=[a-f0-9]+&timestamp=\d+',
    ]
    for pattern in patterns:
        matches = re.findall(pattern, html, re.IGNORECASE)
        if matches:
            audio_url = matches[0]
            file_format = 'wma' if audio_url.lower().endswith('.wma') else 'mp3'
            return audio_url, program_content, file_format

    audio_matches = re.findall(r'<audio[^>]*src=["\']([^"\']+\.(?:mp3|wma)[^"\']*)["\'][^>]*>', html, re.IGNORECASE)
    for audio_url in audio_matches:
        full_url = audio_url if audio_url.startswith('http') else urljoin(BASE_URL, audio_url)
        if "dl2.loveq.cn:8090" in full_url:
            file_format = 'wma' if full_url.lower().endswith('.wma') else 'mp3'
            return full_url, program_content, file_format

    return None, "", None

# --------------------- 下载函数 ---------------------
def download_audio(audio_url, filename, program_url=None):
    try:
        headers = HEADERS.copy()
        if program_url: headers["Referer"] = program_url
        r = session.get(audio_url, headers=headers, stream=True, timeout=30)
        if r.status_code == 200:
            with open(filename, "wb") as f:
                for chunk in r.iter_content(8192):
                    if chunk: f.write(chunk)
            return True
    except: return False
    return False

# --------------------- 多线程处理 ---------------------
def process_single_program(args):
    program, i, total, download_option = args
    result = None
    audio_url, content, file_format = get_audio_url_and_content(program['url'], program['title'])
    if audio_url:
        result = {'original_title': program['title'], 'audio_url': audio_url, 'content': content,
                  'url': program['url'], 'file_format': file_format, 'category_title': program.get('category_title','未知')}
        if download_option=='y':
            ext = file_format if file_format else 'mp3'
            clean_title = re.sub(r'[<>:"/\\|?*]', '_', program['title'])
            os.makedirs(DOWNLOAD_FOLDER, exist_ok=True)
            filename = os.path.join(DOWNLOAD_FOLDER, f"{clean_title}.{ext}")
            result['download_success'] = download_audio(audio_url, filename, program['url'])
    time.sleep(0.2)
    return result

def process_programs_multithread(programs, download_option, mode_name, categories):
    entries, success_count, download_success_count = [], 0, 0
    args = [(p, i+1, len(programs), download_option) for i,p in enumerate(programs)]
    with ThreadPoolExecutor(max_workers=MAX_WORKERS) as executor:
        futures = [executor.submit(process_single_program,arg) for arg in args]
        for future in as_completed(futures):
            try:
                r = future.result()
                if r:
                    entries.append(r)
                    success_count +=1
                    if download_option=='y' and r.get('download_success'): download_success_count+=1
            except: pass
    # 保存链接
    filename = f"loveq_{mode_name}.txt"
    with open(filename,"w",encoding="utf-8") as f:
        for entry in entries:
            f.write(f"{entry['original_title']},{entry['audio_url']}\n")
    print(f"\n🎉 {mode_name}完成！成功处理 {success_count} 个节目，下载成功 {download_success_count} 个")
    print(f"📁 链接已保存: {filename}")

# --------------------- 主函数 ---------------------
def main():
    print("loveq.cn 音频下载工具")
    categories = get_all_categories()
    if not categories: return

    mode = input("选择抓取模式 1:单日 2:年份 3:全站: ").strip()
    download_option = input("是否下载音频？(y/N): ").strip().lower()
    if mode=='1':
        date = input("输入日期 YYYY-MM-DD: ").strip()
        all_programs = []
        for cat in categories:
            all_programs.extend([p for p in get_programs_from_category(cat['id'],cat['title'],year=date.split('-')[0])])
        process_programs_multithread(all_programs, download_option, f"单日_{date}", categories)
    elif mode=='2':
        year = input("输入年份 YYYY: ").strip()
        all_programs=[]
        for cat in categories:
            all_programs.extend(get_programs_from_category(cat['id'],cat['title'],year=year))
        process_programs_multithread(all_programs, download_option, f"年份_{year}", categories)
    elif mode=='3':
        all_programs=[]
        for cat in categories:
            all_programs.extend(get_programs_from_category(cat['id'],cat['title']))
        process_programs_multithread(all_programs, download_option, "全站", categories)

if __name__=="__main__":
    os.makedirs(DOWNLOAD_FOLDER, exist_ok=True)
    main()