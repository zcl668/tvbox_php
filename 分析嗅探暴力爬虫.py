import tkinter as tk
from tkinter import ttk, scrolledtext, messagebox, filedialog
import subprocess
import sys
import os
import threading
import time
import webbrowser
import platform
import urllib.request
import zipfile
import json
import re
import shutil
from pathlib import Path
import requests
from bs4 import BeautifulSoup
from selenium import webdriver
from selenium.webdriver.chrome.options import Options
from selenium.webdriver.common.by import By
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
from selenium.common.exceptions import TimeoutException, WebDriverException
import pkg_resources
import importlib
from concurrent.futures import ThreadPoolExecutor, as_completed
from urllib.parse import urljoin, urlparse
from fake_useragent import UserAgent
import random
import hashlib
import base64

# ==================== 存储空间 - 全球最强爬虫方案 ====================
CRAWLER_SOLUTIONS = """
# ==================== 全球最强爬虫方案库 ====================
# 方案1: 超级暴力爬虫引擎
class SuperViolentCrawler:
    def __init__(self, max_workers=50, headless=True):
        self.max_workers = max_workers
        self.headless = headless
        self.ua = UserAgent()
        self.session = requests.Session()
        self.proxies = self.get_proxy_list()
        self.cookies = {}
        
    def get_proxy_list(self):
        return [
            "http://proxy1.com:8080",
            "http://proxy2.com:8080", 
            "http://proxy3.com:8080"
        ]
    
    def rotate_proxy(self):
        return random.choice(self.proxies) if self.proxies else None
    
    def stealth_driver(self):
        chrome_options = Options()
        if self.headless:
            chrome_options.add_argument("--headless")
        
        # 反检测配置
        chrome_options.add_argument("--disable-blink-features=AutomationControlled")
        chrome_options.add_experimental_option("excludeSwitches", ["enable-automation", "load-extension"])
        chrome_options.add_experimental_option('useAutomationExtension', False)
        chrome_options.add_argument(f"--user-agent={self.ua.random}")
        chrome_options.add_argument("--window-size=1920,1080")
        chrome_options.add_argument("--disable-gpu")
        chrome_options.add_argument("--no-sandbox")
        chrome_options.add_argument("--disable-dev-shm-usage")
        chrome_options.add_argument("--disable-web-security")
        chrome_options.add_argument("--allow-running-insecure-content")
        chrome_options.add_argument("--disable-features=VizDisplayCompositor")
        chrome_options.add_argument("--disable-background-timer-throttling")
        chrome_options.add_argument("--disable-backgrounding-occluded-windows")
        chrome_options.add_argument("--disable-renderer-backgrounding")
        
        # 随机化窗口位置
        chrome_options.add_argument(f"--window-position={random.randint(0,1000)},{random.randint(0,500)}")
        
        driver = webdriver.Chrome(options=chrome_options)
        
        # 执行反检测脚本
        stealth_scripts = [
            "Object.defineProperty(navigator, 'webdriver', {get: () => undefined})",
            "Object.defineProperty(navigator, 'plugins', {get: () => [1, 2, 3]})",
            "Object.defineProperty(navigator, 'languages', {get: () => ['zh-CN', 'zh', 'en']})",
        ]
        
        for script in stealth_scripts:
            driver.execute_script(script)
            
        return driver
"""

# ==================== 多媒体嗅探器 ====================
class MediaSniffer:
    """多媒体嗅探器 - 类似夸克浏览器的视频嗅探功能"""
    
    def __init__(self, max_workers=10):
        self.max_workers = max_workers
        self.ua = UserAgent()
        self.sniffed_data = {}
        self.lock = threading.Lock()
    
    def setup_driver(self):
        """设置浏览器驱动"""
        chrome_options = Options()
        chrome_options.add_argument("--headless")
        chrome_options.add_argument("--disable-blink-features=AutomationControlled")
        chrome_options.add_experimental_option("excludeSwitches", ["enable-automation"])
        chrome_options.add_experimental_option('useAutomationExtension', False)
        chrome_options.add_argument(f"--user-agent={self.ua.random}")
        chrome_options.add_argument("--window-size=1920,1080")
        chrome_options.add_argument("--disable-gpu")
        chrome_options.add_argument("--no-sandbox")
        chrome_options.add_argument("--disable-dev-shm-usage")
        
        driver = webdriver.Chrome(options=chrome_options)
        driver.execute_script("Object.defineProperty(navigator, 'webdriver', {get: () => undefined})")
        return driver
    
    def sniff_media_links(self, url):
        """嗅探页面中的多媒体链接"""
        try:
            driver = self.setup_driver()
            driver.get(url)
            
            # 等待页面加载
            WebDriverWait(driver, 10).until(
                EC.presence_of_element_located((By.TAG_NAME, "body"))
            )
            
            # 获取网络请求记录
            performance_entries = driver.execute_script("""
                return window.performance.getEntriesByType("resource");
            """)
            
            # 分析页面源码
            page_source = driver.page_source
            soup = BeautifulSoup(page_source, 'html.parser')
            
            # 提取各种媒体链接
            media_data = {
                'video_links': self.extract_video_links(page_source, performance_entries),
                'audio_links': self.extract_audio_links(page_source, performance_entries),
                'image_links': self.extract_image_links(page_source, performance_entries),
                'magnet_links': self.extract_magnet_links(page_source),
                'stream_links': self.extract_stream_links(page_source, performance_entries),
                'page_title': driver.title,
                'page_url': url
            }
            
            driver.quit()
            return media_data
            
        except Exception as e:
            print(f"嗅探失败 {url}: {e}")
            return None
    
    def extract_video_links(self, html, performance_entries):
        """提取视频链接"""
        video_links = []
        
        # 从性能记录中提取
        for entry in performance_entries:
            if any(ext in entry['name'].lower() for ext in ['.mp4', '.m3u8', '.avi', '.mov', '.wmv', '.flv', '.webm']):
                video_links.append(entry['name'])
        
        # 从HTML中提取
        video_patterns = [
            r'https?://[^\s"\']+\.(mp4|m3u8|avi|mov|wmv|flv|webm)[^\s"\']*',
            r'video[^>]*src=["\']([^"\']+)["\']',
            r'data-video-url=["\']([^"\']+)["\']',
            r'file["\']?\s*:\s*["\']([^"\']+\.(mp4|m3u8))["\']',
            r'source[^>]*src=["\']([^"\']+)["\']'
        ]
        
        for pattern in video_patterns:
            matches = re.findall(pattern, html, re.IGNORECASE)
            for match in matches:
                if isinstance(match, tuple):
                    url = match[0]
                else:
                    url = match
                
                if url.startswith('//'):
                    url = 'https:' + url
                
                if url not in video_links:
                    video_links.append(url)
        
        return list(set(video_links))
    
    def extract_audio_links(self, html, performance_entries):
        """提取音频链接"""
        audio_links = []
        
        # 从性能记录中提取
        for entry in performance_entries:
            if any(ext in entry['name'].lower() for ext in ['.mp3', '.wav', '.aac', '.ogg', '.m4a']):
                audio_links.append(entry['name'])
        
        # 从HTML中提取
        audio_patterns = [
            r'https?://[^\s"\']+\.(mp3|wav|aac|ogg|m4a)[^\s"\']*',
            r'audio[^>]*src=["\']([^"\']+)["\']',
            r'data-audio-url=["\']([^"\']+)["\']'
        ]
        
        for pattern in audio_patterns:
            matches = re.findall(pattern, html, re.IGNORECASE)
            for match in matches:
                if isinstance(match, tuple):
                    url = match[0]
                else:
                    url = match
                
                if url.startswith('//'):
                    url = 'https:' + url
                
                if url not in audio_links:
                    audio_links.append(url)
        
        return list(set(audio_links))
    
    def extract_image_links(self, html, performance_entries):
        """提取图片链接"""
        image_links = []
        
        # 从性能记录中提取
        for entry in performance_entries:
            if any(ext in entry['name'].lower() for ext in ['.jpg', '.jpeg', '.png', '.gif', '.webp', '.bmp']):
                image_links.append(entry['name'])
        
        # 从HTML中提取
        soup = BeautifulSoup(html, 'html.parser')
        img_tags = soup.find_all('img', src=True)
        for img in img_tags:
            src = img['src']
            if src.startswith('//'):
                src = 'https:' + src
            if src not in image_links:
                image_links.append(src)
        
        return list(set(image_links))
    
    def extract_magnet_links(self, html):
        """提取磁力链接"""
        magnet_pattern = r'magnet:\?[^\s"\']+'
        magnet_links = re.findall(magnet_pattern, html, re.IGNORECASE)
        return list(set(magnet_links))
    
    def extract_stream_links(self, html, performance_entries):
        """提取流媒体链接"""
        stream_links = []
        
        # HLS流
        hls_patterns = [
            r'https?://[^\s"\']+\.m3u8[^\s"\']*',
            r'hls[^>]*url=["\']([^"\']+)["\']',
            r'stream[^>]*url=["\']([^"\']+)["\']'
        ]
        
        for pattern in hls_patterns:
            matches = re.findall(pattern, html, re.IGNORECASE)
            for match in matches:
                if isinstance(match, tuple):
                    url = match[0]
                else:
                    url = match
                
                if url.startswith('//'):
                    url = 'https:' + url
                
                if url not in stream_links:
                    stream_links.append(url)
        
        return list(set(stream_links))
    
    def batch_sniff_videos(self, video_urls, callback=None):
        """批量嗅探视频"""
        print(f"开始批量嗅探 {len(video_urls)} 个视频...")
        
        with ThreadPoolExecutor(max_workers=self.max_workers) as executor:
            futures = {}
            
            for i, url in enumerate(video_urls):
                future = executor.submit(self.sniff_media_links, url)
                futures[future] = (i, url)
            
            completed = 0
            total = len(video_urls)
            
            for future in as_completed(futures):
                i, url = futures[future]
                try:
                    result = future.result()
                    if result:
                        with self.lock:
                            self.sniffed_data[url] = result
                    
                    completed += 1
                    if callback:
                        callback(completed, total, f"嗅探进度: {completed}/{total}")
                    
                    print(f"嗅探完成 {completed}/{total}: {url}")
                    
                except Exception as e:
                    print(f"嗅探失败 {url}: {e}")
                    completed += 1
        
        print(f"批量嗅探完成! 成功: {len(self.sniffed_data)}/{total}")
        return self.sniffed_data

# ==================== 视频链接提取器 ====================
class VideoLinkExtractor:
    """视频链接提取器 - 专门用于解析视频播放链接和磁力链接"""
    
    def __init__(self):
        self.ua = UserAgent()
        self.sniffer = MediaSniffer()
    
    def extract_video_links(self, video_page_url):
        """从视频页面提取视频播放链接和磁力链接"""
        try:
            # 使用多媒体嗅探器
            media_data = self.sniffer.sniff_media_links(video_page_url)
            
            if media_data:
                # 生成可播放链接
                playable_links = self.generate_playable_links(media_data)
                
                video_info = {
                    'page_url': video_page_url,
                    'title': media_data.get('page_title', '未知标题'),
                    'video_links': media_data.get('video_links', []),
                    'magnet_links': media_data.get('magnet_links', []),
                    'playable_links': playable_links,
                    'audio_links': media_data.get('audio_links', []),
                    'image_links': media_data.get('image_links', []),
                    'stream_links': media_data.get('stream_links', [])
                }
                
                return video_info
            
        except Exception as e:
            print(f"提取视频链接失败 {video_page_url}: {e}")
        
        return None
    
    def generate_playable_links(self, media_data):
        """生成可播放链接"""
        playable_links = []
        
        # 视频播放链接
        for video_url in media_data.get('video_links', []):
            if video_url.endswith('.m3u8'):
                playable_links.append({
                    'type': 'HLS流',
                    'url': video_url,
                    'player': f'https://hlsplayer.net/?url={video_url}'
                })
            elif video_url.endswith('.mp4'):
                playable_links.append({
                    'type': 'MP4直链',
                    'url': video_url,
                    'player': f'https://cdn.plyr.io/player.html?url={video_url}'
                })
        
        # 流媒体链接
        for stream_url in media_data.get('stream_links', []):
            playable_links.append({
                'type': '流媒体',
                'url': stream_url,
                'player': f'https://hlsplayer.net/?url={stream_url}'
            })
        
        # 磁力链接
        for magnet_link in media_data.get('magnet_links', []):
            playable_links.append({
                'type': '磁力链接',
                'url': magnet_link,
                'player': f'https://webtor.io/#/player?magnet={magnet_link}'
            })
        
        return playable_links

# ==================== JableTV爬虫类 ====================
class JableTVCrawler:
    """JableTV全站爬虫 - 增强版本"""
    def __init__(self, max_workers=18, headless=True, target_url=None, knowledge_base=None):
        self.max_workers = max_workers
        self.headless = headless
        self.ua = UserAgent()
        self.base_url = target_url if target_url else "https://jable.tv/"
        self.categories = []
        self.all_videos = []
        self.lock = threading.Lock()
        self.link_extractor = VideoLinkExtractor()
        self.knowledge_base = knowledge_base  # 智库引用
        
        # 创建基础文件夹
        self.base_dir = "jabletv"
        if not os.path.exists(self.base_dir):
            os.makedirs(self.base_dir)
            print(f"创建文件夹: {self.base_dir}")
    
    def setup_driver(self):
        """设置浏览器驱动"""
        chrome_options = Options()
        
        if self.headless:
            chrome_options.add_argument("--headless")
        
        chrome_options.add_argument("--disable-blink-features=AutomationControlled")
        chrome_options.add_experimental_option("excludeSwitches", ["enable-automation"])
        chrome_options.add_experimental_option('useAutomationExtension', False)
        chrome_options.add_argument(f"--user-agent={self.ua.random}")
        chrome_options.add_argument("--window-size=1920,1080")
        chrome_options.add_argument("--disable-gpu")
        chrome_options.add_argument("--no-sandbox")
        chrome_options.add_argument("--disable-dev-shm-usage")
        
        try:
            driver = webdriver.Chrome(options=chrome_options)
            driver.execute_script("Object.defineProperty(navigator, 'webdriver', {get: () => undefined})")
            return driver
        except Exception as e:
            print(f"创建浏览器驱动失败: {e}")
            return None

    def get_categories(self):
        """获取全部分类"""
        print("正在获取分类列表...")
        driver = self.setup_driver()
        if not driver:
            return []
        
        try:
            driver.get(self.base_url)
            WebDriverWait(driver, 10).until(
                EC.presence_of_element_located((By.TAG_NAME, "body"))
            )
            
            # 查找导航栏和分类链接
            page_source = driver.page_source
            soup = BeautifulSoup(page_source, 'html.parser')
            
            # 多种选择器尝试查找分类
            category_selectors = [
                "nav a[href*='/categories/']",
                "nav a[href*='/models/']", 
                "nav a[href*='/tags/']",
                ".menu a[href*='/categories/']",
                ".navigation a[href*='/categories/']",
                "a[href*='/categories/']",
                "a[href*='/models/']",
                "a[href*='/tags/']"
            ]
            
            categories = []
            for selector in category_selectors:
                links = soup.select(selector)
                for link in links:
                    href = link.get('href')
                    text = link.get_text(strip=True)
                    
                    if href and text and len(text) > 1 and len(text) < 50:
                        full_url = href if href.startswith('http') else urljoin(self.base_url, href)
                        
                        # 去重
                        if not any(c['url'] == full_url for c in categories):
                            categories.append({
                                'name': text,
                                'url': full_url
                            })
            
            print(f"找到 {len(categories)} 个分类")
            return categories
            
        except Exception as e:
            print(f"获取分类失败: {e}")
            return []
        finally:
            driver.quit()
    
    def get_category_pages(self, category_url):
        """获取分类的总页数"""
        driver = self.setup_driver()
        if not driver:
            return 1
        
        try:
            driver.get(category_url)
            time.sleep(2)
            
            # 多种方式获取页数
            page_numbers = []
            
            # 方法1: 查找分页元素
            pagination_selectors = [
                ".pagination a",
                ".page-numbers a", 
                ".pages a",
                "a[href*='page=']"
            ]
            
            for selector in pagination_selectors:
                try:
                    elements = driver.find_elements(By.CSS_SELECTOR, selector)
                    for element in elements:
                        try:
                            text = element.text.strip()
                            if text.isdigit():
                                page_numbers.append(int(text))
                        except:
                            continue
                except:
                    continue
            
            # 方法2: 从URL参数获取
            current_url = driver.current_url
            if 'page=' in current_url:
                match = re.search(r'page=(\d+)', current_url)
                if match:
                    page_numbers.append(int(match.group(1)))
            
            if page_numbers:
                max_pages = max(page_numbers)
                print(f"分类页面检测到 {max_pages} 页")
                return max_pages
            else:
                print("未检测到分页，默认为1页")
                return 1
                
        except Exception as e:
            print(f"获取分类页数失败: {e}")
            return 1
        finally:
            driver.quit()
    
    def get_videos_from_page(self, page_url, category_name):
        """从页面获取视频列表"""
        driver = self.setup_driver()
        if not driver:
            return []
        
        try:
            driver.get(page_url)
            time.sleep(2)
            
            # 查找视频链接
            video_selectors = [
                "a[href*='/videos/']",
                "a[href*='/video/']",
                ".video-item a",
                ".post a"
            ]
            
            videos = []
            for selector in video_selectors:
                try:
                    elements = driver.find_elements(By.CSS_SELECTOR, selector)
                    for element in elements:
                        try:
                            href = element.get_attribute('href')
                            title = element.get_attribute('title') or element.text or "未知标题"
                            
                            if href and '/videos/' in href and title.strip():
                                # 如果有智库数据，直接使用
                                video_info = None
                                if self.knowledge_base and hasattr(self.knowledge_base, 'sniffed_data'):
                                    sniffed_data = self.knowledge_base.sniffed_data.get(href)
                                    if sniffed_data:
                                        playable_links = self.link_extractor.generate_playable_links(sniffed_data)
                                        video_info = {
                                            'title': sniffed_data.get('page_title', title),
                                            'page_url': href,
                                            'category': category_name,
                                            'video_links': sniffed_data.get('video_links', []),
                                            'magnet_links': sniffed_data.get('magnet_links', []),
                                            'playable_links': playable_links,
                                            'extracted_time': time.strftime('%Y-%m-%d %H:%M:%S'),
                                            'source': '智库嗅探'
                                        }
                                
                                # 如果没有智库数据，正常提取
                                if not video_info:
                                    video_details = self.link_extractor.extract_video_links(href)
                                    if video_details:
                                        video_info = {
                                            'title': video_details['title'],
                                            'page_url': href,
                                            'category': category_name,
                                            'video_links': video_details['video_links'],
                                            'magnet_links': video_details['magnet_links'],
                                            'playable_links': video_details['playable_links'],
                                            'extracted_time': time.strftime('%Y-%m-%d %H:%M:%S'),
                                            'source': '实时解析'
                                        }
                                
                                if video_info:
                                    # 去重
                                    if not any(v['page_url'] == href for v in videos):
                                        videos.append(video_info)
                                    
                        except Exception as e:
                            continue
                except:
                    continue
            
            print(f"从页面 {page_url} 找到 {len(videos)} 个视频")
            return videos
            
        except Exception as e:
            print(f"从页面获取视频失败 {page_url}: {e}")
            return []
        finally:
            driver.quit()
    
    def crawl_category(self, category, progress_callback=None):
        """爬取单个分类的所有视频"""
        category_name = category['name']
        category_url = category['url']
        
        print(f"开始爬取分类: {category_name}")
        
        # 创建分类文件夹 - 去掉特殊符号
        clean_category_name = re.sub(r'[#,]', '', category_name).strip()
        category_dir = os.path.join(self.base_dir, clean_category_name)
        if not os.path.exists(category_dir):
            os.makedirs(category_dir)
        
        # 获取总页数
        total_pages = self.get_category_pages(category_url)
        print(f"分类 {category_name} 共有 {total_pages} 页")
        
        all_category_videos = []
        
        # 爬取每一页
        for page in range(1, total_pages + 1):
            print(f"爬取 {category_name} 第 {page}/{total_pages} 页")
            
            if page == 1:
                page_url = category_url
            else:
                # 构造分页URL
                if '?' in category_url:
                    page_url = f"{category_url}&page={page}"
                else:
                    page_url = f"{category_url}?page={page}"
            
            page_videos = self.get_videos_from_page(page_url, category_name)
            all_category_videos.extend(page_videos)
            
            # 调用进度回调
            if progress_callback:
                progress_callback(len(all_category_videos), f"分类 {category_name}: 已获取 {len(all_category_videos)} 个视频")
            
            # 随机延迟，避免请求过快
            time.sleep(random.uniform(1, 3))
        
        # 保存视频链接
        if all_category_videos:
            self.save_category_videos(all_category_videos, category_dir, category_name)
        
        # 添加到总视频列表
        with self.lock:
            self.all_videos.extend(all_category_videos)
        
        return len(all_category_videos)
    
    def save_category_videos(self, videos, category_dir, category_name):
        """保存分类视频链接到文件"""
        try:
            # 保存详细视频信息
            video_file = os.path.join(category_dir, "videos_detailed.txt")
            
            with open(video_file, 'w', encoding='utf-8') as f:
                f.write(f"# {category_name} 视频详细信息\n")
                f.write(f"# 生成时间: {time.strftime('%Y-%m-%d %H:%M:%S')}\n")
                f.write(f"# 视频数量: {len(videos)}\n\n")
                
                for i, video in enumerate(videos, 1):
                    f.write(f"=== 视频 {i}: {video['title']} ===\n")
                    f.write(f"页面链接: {video['page_url']}\n")
                    f.write(f"分类: {video['category']}\n")
                    f.write(f"提取时间: {video['extracted_time']}\n")
                    f.write(f"数据来源: {video.get('source', '未知')}\n\n")
                    
                    # 视频播放链接
                    if video['video_links']:
                        f.write("视频播放链接:\n")
                        for j, link in enumerate(video['video_links'], 1):
                            f.write(f"  {j}. {link}\n")
                        f.write("\n")
                    
                    # 磁力链接
                    if video['magnet_links']:
                        f.write("磁力链接:\n")
                        for j, link in enumerate(video['magnet_links'], 1):
                            f.write(f"  {j}. {link}\n")
                        f.write("\n")
                    
                    # 可播放链接
                    if video['playable_links']:
                        f.write("可播放链接:\n")
                        for j, link_info in enumerate(video['playable_links'], 1):
                            f.write(f"  {j}. {link_info['type']}:\n")
                            f.write(f"     原始链接: {link_info['url']}\n")
                            f.write(f"     播放器: {link_info['player']}\n")
                        f.write("\n")
                    
                    f.write("-" * 50 + "\n\n")
            
            # 保存简化的播放链接文件
            playable_file = os.path.join(category_dir, "playable_links.txt")
            with open(playable_file, 'w', encoding='utf-8') as f:
                f.write(f"# {category_name} 可播放链接\n")
                f.write(f"# 生成时间: {time.strftime('%Y-%m-%d %H:%M:%S')}\n\n")
                
                for video in videos:
                    if video['playable_links']:
                        f.write(f"# {video['title']}\n")
                        for link_info in video['playable_links']:
                            f.write(f"{link_info['player']}\n")
                        f.write("\n")
            
            print(f"已保存 {len(videos)} 个视频详细信息到 {video_file}")
            print(f"已保存可播放链接到 {playable_file}")
            
        except Exception as e:
            print(f"保存视频链接失败: {e}")
    
    def crawl_all(self, progress_callback=None):
        """爬取全部分类"""
        print("开始爬取JableTV全站视频...")
        start_time = time.time()
        
        # 获取分类列表
        self.categories = self.get_categories()
        if not self.categories:
            print("未找到任何分类，退出爬取")
            return
        
        print(f"开始爬取 {len(self.categories)} 个分类，使用 {self.max_workers} 个线程")
        
        # 使用线程池爬取所有分类
        with ThreadPoolExecutor(max_workers=self.max_workers) as executor:
            futures = []
            
            for category in self.categories:
                future = executor.submit(self.crawl_category, category, progress_callback)
                futures.append(future)
            
            # 等待所有任务完成并统计结果
            category_results = []
            for future in as_completed(futures):
                try:
                    result = future.result()
                    category_results.append(result)
                except Exception as e:
                    print(f"分类爬取失败: {e}")
                    category_results.append(0)
        
        # 生成总报告
        total_videos = len(self.all_videos)
        end_time = time.time()
        elapsed_time = end_time - start_time
        
        report = {
            "crawl_time": time.strftime("%Y-%m-%d %H:%M:%S"),
            "elapsed_seconds": round(elapsed_time, 2),
            "total_categories": len(self.categories),
            "total_videos": total_videos,
            "categories": [
                {
                    "name": category['name'],
                    'url': category['url']
                } for category in self.categories
            ]
        }
        
        # 保存总报告
        report_file = os.path.join(self.base_dir, "crawl_report.json")
        with open(report_file, 'w', encoding='utf-8') as f:
            json.dump(report, f, indent=2, ensure_ascii=False)
        
        print(f"\n爬取完成!")
        print(f"总分类数: {len(self.categories)}")
        print(f"总视频数: {total_videos}")
        print(f"耗时: {elapsed_time:.2f} 秒")
        print(f"平均速度: {total_videos/elapsed_time:.2f} 视频/秒")
        print(f"报告已保存到: {report_file}")
        return report

# ==================== 智库系统 ====================
class KnowledgeBase:
    """智库系统 - 多媒体智能分析与嗅探中心"""
    
    def __init__(self, root):
        self.root = root
        self.root.title("🧠 智库 - 多媒体智能分析与嗅探中心")
        self.root.geometry("1000x800")
        self.root.configure(bg='#2c3e50')
        
        # 状态变量
        self.analysis_in_progress = False
        self.sniffing_in_progress = False
        self.current_step = 0
        self.total_steps = 0
        self.analysis_result = {}
        self.sniffed_data = {}
        self.target_url = "https://jable.tv/"
        
        # 多媒体嗅探器
        self.media_sniffer = MediaSniffer(max_workers=8)
        
        # 必需包列表
        self.required_packages = [
            "requests", "beautifulsoup4", "selenium", "fake-useragent"
        ]
        
        # 创建UI组件
        self.setup_styles()
        self.create_widgets()
        
        # 自动开始环境检测
        self.root.after(1000, self.start_environment_check)
    
    def setup_styles(self):
        """设置美化样式"""
        style = ttk.Style()
        
        # 配置样式
        style.configure('Custom.TFrame', background='#34495e')
        style.configure('Custom.TLabelframe', background='#34495e', foreground='white')
        style.configure('Custom.TLabel', background='#34495e', foreground='white', font=('Microsoft YaHei', 10))
        style.configure('Title.TLabel', background='#34495e', foreground='#e74c3c', font=('Microsoft YaHei', 18, 'bold'))
        style.configure('Accent.TButton', background='#27ae60', foreground='white', font=('Microsoft YaHei', 10, 'bold'))
        style.configure('Action.TButton', background='#3498db', foreground='white', font=('Microsoft YaHei', 10))
        style.configure('Warning.TButton', background='#e74c3c', foreground='white', font=('Microsoft YaHei', 10))
        style.configure('Custom.Horizontal.TProgressbar', background='#27ae60')
    
    def create_widgets(self):
        """创建UI组件"""
        # 主框架
        main_frame = ttk.Frame(self.root, padding="15", style='Custom.TFrame')
        main_frame.grid(row=0, column=0, sticky=(tk.W, tk.E, tk.N, tk.S))
        
        # 标题
        title_label = ttk.Label(main_frame, text="🧠 智库 - 多媒体智能分析与嗅探中心", 
                               font=("Microsoft YaHei", 18, "bold"), style='Title.TLabel')
        title_label.grid(row=0, column=0, columnspan=3, pady=(0, 20))
        
        # 目标网站输入框
        url_frame = ttk.LabelFrame(main_frame, text="🌐 目标网站设置", padding="10", style='Custom.TLabelframe')
        url_frame.grid(row=1, column=0, columnspan=3, sticky=(tk.W, tk.E), pady=(0, 10))
        
        ttk.Label(url_frame, text="目标网址:", style='Custom.TLabel').grid(row=0, column=0, sticky=tk.W)
        self.url_var = tk.StringVar(value=self.target_url)
        url_entry = ttk.Entry(url_frame, textvariable=self.url_var, width=60, font=('Microsoft YaHei', 10))
        url_entry.grid(row=0, column=1, padx=(10, 10), sticky=(tk.W, tk.E))
        
        url_test_button = ttk.Button(url_frame, text="🔍 测试连接", 
                                    command=self.test_connection, style='Action.TButton')
        url_test_button.grid(row=0, column=2, padx=(0, 10))
        
        url_analyze_button = ttk.Button(url_frame, text="🚀 智能分析", 
                                       command=self.start_smart_analysis, style='Accent.TButton')
        url_analyze_button.grid(row=0, column=3, padx=(0, 10))
        
        url_frame.columnconfigure(1, weight=1)
        
        # 进度显示
        progress_frame = ttk.LabelFrame(main_frame, text="📊 分析进度", padding="10", style='Custom.TLabelframe')
        progress_frame.grid(row=2, column=0, columnspan=3, sticky=(tk.W, tk.E), pady=(0, 10))
        
        self.progress_label = ttk.Label(progress_frame, text="🟢 准备开始环境检测...", style='Custom.TLabel')
        self.progress_label.grid(row=0, column=0, sticky=tk.W)
        
        self.progress_bar = ttk.Progressbar(progress_frame, mode='determinate', style='Custom.Horizontal.TProgressbar')
        self.progress_bar.grid(row=1, column=0, sticky=(tk.W, tk.E), pady=(5, 0))
        
        # 包状态显示
        package_frame = ttk.LabelFrame(main_frame, text="🔧 系统组件状态", padding="10", style='Custom.TLabelframe')
        package_frame.grid(row=3, column=0, columnspan=3, sticky=(tk.W, tk.E), pady=(0, 10))
        
        self.package_tree = ttk.Treeview(package_frame, columns=('status', 'version'), 
                                       height=6, style='Custom.Treeview')
        self.package_tree.heading('#0', text='组件名称')
        self.package_tree.heading('status', text='状态')
        self.package_tree.heading('version', text='版本')
        self.package_tree.column('#0', width=200)
        self.package_tree.column('status', width=100)
        self.package_tree.column('version', width=100)
        
        scrollbar = ttk.Scrollbar(package_frame, orient="vertical", command=self.package_tree.yview)
        self.package_tree.configure(yscrollcommand=scrollbar.set)
        
        self.package_tree.grid(row=0, column=0, sticky=(tk.W, tk.E, tk.N, tk.S))
        scrollbar.grid(row=0, column=1, sticky=(tk.N, tk.S))
        
        # 网站分析结果显示
        analysis_frame = ttk.LabelFrame(main_frame, text="📊 网站分析结果", padding="10", style='Custom.TLabelframe')
        analysis_frame.grid(row=4, column=0, columnspan=2, sticky=(tk.W, tk.E, tk.N, tk.S), pady=(0, 10))
        
        self.analysis_text = scrolledtext.ScrolledText(analysis_frame, height=12, bg='#ecf0f1', fg='#2c3e50',
                                                     font=("Consolas", 9))
        self.analysis_text.grid(row=0, column=0, sticky=(tk.W, tk.E, tk.N, tk.S))
        
        # 嗅探控制面板
        sniff_frame = ttk.LabelFrame(main_frame, text="🎯 多媒体嗅探控制", padding="10", style='Custom.TLabelframe')
        sniff_frame.grid(row=4, column=2, sticky=(tk.W, tk.E, tk.N, tk.S), pady=(0, 10), padx=(10, 0))
        
        # 嗅探配置
        config_frame = ttk.Frame(sniff_frame, style='Custom.TFrame')
        config_frame.grid(row=0, column=0, sticky=(tk.W, tk.E), pady=(0, 10))
        
        ttk.Label(config_frame, text="嗅探线程:", style='Custom.TLabel').grid(row=0, column=0, sticky=tk.W)
        self.sniff_threads_var = tk.StringVar(value="8")
        sniff_threads_combo = ttk.Combobox(config_frame, textvariable=self.sniff_threads_var,
                                          values=["1", "4", "8", "12", "16"], width=8)
        sniff_threads_combo.grid(row=0, column=1, padx=(5, 20), sticky=tk.W)
        
        ttk.Label(config_frame, text="嗅探类型:", style='Custom.TLabel').grid(row=0, column=2, sticky=tk.W)
        self.sniff_type_var = tk.StringVar(value="全部媒体")
        sniff_type_combo = ttk.Combobox(config_frame, textvariable=self.sniff_type_var,
                                       values=["全部媒体", "仅视频", "仅音频", "仅图片", "仅磁力"], width=10)
        sniff_type_combo.grid(row=0, column=3, padx=(5, 0), sticky=tk.W)
        
        # 嗅探按钮
        sniff_button_frame = ttk.Frame(sniff_frame, style='Custom.TFrame')
        sniff_button_frame.grid(row=1, column=0, sticky=(tk.W, tk.E), pady=(0, 10))
        
        self.start_sniff_button = ttk.Button(sniff_button_frame, text="🔍 开始多媒体嗅探", 
                                           command=self.start_media_sniffing, style='Accent.TButton')
        self.start_sniff_button.grid(row=0, column=0, padx=(0, 10))
        
        self.stop_sniff_button = ttk.Button(sniff_button_frame, text="⏹️ 停止嗅探", 
                                          command=self.stop_media_sniffing, state=tk.DISABLED, style='Warning.TButton')
        self.stop_sniff_button.grid(row=0, column=1, padx=(0, 10))
        
        # 嗅探结果统计
        stats_frame = ttk.Frame(sniff_frame, style='Custom.TFrame')
        stats_frame.grid(row=2, column=0, sticky=(tk.W, tk.E), pady=(0, 10))
        
        self.stats_label = ttk.Label(stats_frame, text="📈 嗅探统计: 等待开始...", style='Custom.TLabel')
        self.stats_label.grid(row=0, column=0, sticky=tk.W)
        
        # 日志输出部分
        log_frame = ttk.LabelFrame(main_frame, text="📝 系统日志", padding="10", style='Custom.TLabelframe')
        log_frame.grid(row=5, column=0, columnspan=3, sticky=(tk.W, tk.E, tk.N, tk.S), pady=(10, 0))
        
        self.log_text = scrolledtext.ScrolledText(log_frame, height=12, bg='#1a1a1a', fg='#00ff00',
                                                font=("Consolas", 9))
        self.log_text.grid(row=0, column=0, sticky=(tk.W, tk.E, tk.N, tk.S))
        
        # 控制按钮
        button_frame = ttk.Frame(main_frame, style='Custom.TFrame')
        button_frame.grid(row=6, column=0, columnspan=3, pady=15)
        
        self.launch_crawler_button = ttk.Button(button_frame, text="🤖 启动智能小扒手", 
                                              command=self.launch_smart_crawler, style='Accent.TButton')
        self.launch_crawler_button.grid(row=0, column=0, padx=(0, 10))
        
        self.auto_mode_button = ttk.Button(button_frame, text="🚀 全自动模式", 
                                         command=self.start_auto_mode, style='Action.TButton')
        self.auto_mode_button.grid(row=0, column=1, padx=(0, 10))
        
        self.repair_button = ttk.Button(button_frame, text="🔧 自动修复", 
                                      command=self.auto_repair, style='Action.TButton')
        self.repair_button.grid(row=0, column=2, padx=(0, 10))
        
        self.quit_button = ttk.Button(button_frame, text="🚪 退出", 
                                    command=self.root.quit, style='Warning.TButton')
        self.quit_button.grid(row=0, column=3, padx=(0, 10))
        
        # 配置网格权重
        self.root.columnconfigure(0, weight=1)
        self.root.rowconfigure(0, weight=1)
        main_frame.columnconfigure(0, weight=1)
        main_frame.rowconfigure(4, weight=1)
        main_frame.rowconfigure(5, weight=1)
        log_frame.columnconfigure(0, weight=1)
        log_frame.rowconfigure(0, weight=1)
        analysis_frame.columnconfigure(0, weight=1)
        analysis_frame.rowconfigure(0, weight=1)
        sniff_frame.columnconfigure(0, weight=1)
        package_frame.columnconfigure(0, weight=1)
        package_frame.rowconfigure(0, weight=1)
        progress_frame.columnconfigure(0, weight=1)
    
    def log_message(self, message):
        """在日志区域添加消息"""
        self.log_text.insert(tk.END, f"{time.strftime('%H:%M:%S')} - {message}\n")
        self.log_text.see(tk.END)
        self.root.update_idletasks()
    
    def update_progress(self, step, total, message):
        """更新进度条和标签"""
        self.current_step = step
        self.total_steps = total
        progress_percent = (step / total) * 100
        self.progress_bar['value'] = progress_percent
        self.progress_label.config(text=f"{message} ({step}/{total})")
        self.root.update_idletasks()
    
    def update_component_status(self, component, status, version=""):
        """更新组件状态"""
        for item in self.package_tree.get_children():
            if self.package_tree.item(item, 'text') == component:
                self.package_tree.set(item, 'status', status)
                self.package_tree.set(item, 'version', version)
                return
        
        # 如果组件不在列表中，添加它
        self.package_tree.insert('', 'end', text=component, values=(status, version))
    
    def test_connection(self):
        """测试网站连接"""
        url = self.url_var.get().strip()
        if not url:
            messagebox.showwarning("警告", "请输入目标网址")
            return
        
        self.log_message(f"🔗 测试连接: {url}")
        
        try:
            response = requests.get(url, timeout=10)
            if response.status_code == 200:
                self.log_message("✅ 连接成功!")
                self.target_url = url
                messagebox.showinfo("连接测试", "连接成功!")
            else:
                self.log_message(f"⚠️ 连接异常: 状态码 {response.status_code}")
                messagebox.showwarning("连接测试", f"连接异常: 状态码 {response.status_code}")
        except Exception as e:
            self.log_message(f"❌ 连接失败: {str(e)}")
            messagebox.showerror("连接测试", f"连接失败: {str(e)}")
    
    def start_environment_check(self):
        """开始环境检测"""
        self.log_message("🚀 开始系统环境检测...")
        
        # 在新线程中运行环境检测
        thread = threading.Thread(target=self.environment_check_process)
        thread.daemon = True
        thread.start()
    
    def environment_check_process(self):
        """环境检测过程"""
        try:
            # 步骤1: 检查系统环境
            self.update_progress(1, 3, "检查系统环境")
            self.log_message("📋 步骤 1/3: 检查系统环境")
            system_info = platform.platform()
            self.log_message(f"💻 系统信息: {system_info}")
            
            # 步骤2: 检查Python环境
            self.update_progress(2, 3, "检查Python环境")
            self.log_message("🐍 步骤 2/3: 检查Python环境")
            python_info = f"{platform.python_implementation()} {platform.python_version()}"
            self.log_message(f"Python信息: {python_info}")
            
            # 步骤3: 检查Python包
            self.update_progress(3, 3, "检查Python包")
            self.log_message("📦 步骤 3/3: 检查Python包")
            self.check_python_packages()
            
            # 完成环境检测
            self.log_message("✅ 环境检测完成!")
            
        except Exception as e:
            self.log_message(f"❌ 环境检测过程中出现错误: {str(e)}")
    
    def check_python_packages(self):
        """检查Python包"""
        for package in self.required_packages:
            try:
                # 确定导入名称
                if package == "beautifulsoup4":
                    import_name = "bs4"
                elif package == "fake-useragent":
                    import_name = "fake_useragent"
                else:
                    import_name = package
                
                # 尝试导入包
                module = __import__(import_name)
                version = getattr(module, '__version__', '未知版本')
                
                # 尝试通过pkg_resources获取更准确的版本
                try:
                    dist = pkg_resources.get_distribution(package)
                    version = dist.version
                except:
                    pass
                
                self.update_component_status(package, "✅ 已安装", version)
                
            except ImportError:
                self.update_component_status(package, "❌ 未安装", "")
    
    def start_smart_analysis(self):
        """开始智能分析"""
        if self.analysis_in_progress:
            return
        
        self.analysis_in_progress = True
        self.target_url = self.url_var.get().strip()
        
        # 在新线程中运行分析过程
        thread = threading.Thread(target=self.smart_analysis_process)
        thread.daemon = True
        thread.start()
    
    def smart_analysis_process(self):
        """智能分析过程"""
        try:
            # 步骤1: 安装缺失的包
            self.update_progress(1, 5, "安装缺失组件")
            self.log_message("📦 步骤 1/5: 安装缺失组件")
            self.install_missing_packages()
            
            # 步骤2: 测试基础功能
            self.update_progress(2, 5, "测试基础功能")
            self.log_message("🔧 步骤 2/5: 测试爬虫基础功能")
            basic_test_passed = self.test_basic_functionality()
            
            # 步骤3: 访问目标网站
            self.update_progress(3, 5, "访问目标网站")
            self.log_message("🌐 步骤 3/5: 访问目标网站")
            website_accessible = self.access_target_website()
            
            # 步骤4: 深度分析网站结构
            self.update_progress(4, 5, "深度分析网站")
            self.log_message("🔍 步骤 4/5: 深度分析网站结构")
            self.deep_analyze_website()
            
            # 步骤5: 生成分析报告
            self.update_progress(5, 5, "生成分析报告")
            self.log_message("📊 步骤 5/5: 生成分析报告")
            self.generate_analysis_report()
            
            self.log_message("✅ 智能分析完成!")
            
            # 自动开始多媒体嗅探
            self.log_message("🎯 自动开始多媒体嗅探...")
            self.root.after(1000, self.start_media_sniffing)
            
        except Exception as e:
            self.log_message(f"❌ 智能分析过程中出现错误: {str(e)}")
        
        self.analysis_in_progress = False
    
    def install_missing_packages(self):
        """安装缺失的包"""
        for package in self.required_packages:
            # 检查包状态
            status = ""
            for item in self.package_tree.get_children():
                if self.package_tree.item(item, 'text') == package:
                    status = self.package_tree.set(item, 'status')
                    break
            
            if status == "❌ 未安装":
                self.log_message(f"📦 正在安装 {package}...")
                try:
                    # 使用pip安装包
                    subprocess.check_call([sys.executable, "-m", "pip", "install", package])
                    
                    # 获取版本信息
                    try:
                        dist = pkg_resources.get_distribution(package)
                        version = dist.version
                    except:
                        version = "未知版本"
                    
                    self.update_component_status(package, "✅ 已安装", version)
                    self.log_message(f"✅ {package} 安装成功")
                    
                except subprocess.CalledProcessError as e:
                    self.update_component_status(package, "❌ 安装失败", "")
                    self.log_message(f"❌ {package} 安装失败: {e}")
    
    def test_basic_functionality(self):
        """测试基础功能"""
        try:
            # 测试requests
            response = requests.get("https://httpbin.org/get", timeout=10)
            if response.status_code == 200:
                self.log_message("✅ Requests功能正常")
            else:
                self.log_message("❌ Requests功能异常")
                return False
            
            # 测试BeautifulSoup
            html = "<html><body><h1>Test</h1><div class='test'>Content</div></body></html>"
            soup = BeautifulSoup(html, 'html.parser')
            if soup.find('h1').text == "Test" and soup.find('div', class_='test'):
                self.log_message("✅ BeautifulSoup功能正常")
            else:
                self.log_message("❌ BeautifulSoup功能异常")
                return False
            
            # 测试Selenium
            try:
                from selenium import webdriver
                from selenium.webdriver.chrome.options import Options
                
                options = Options()
                options.add_argument("--headless")
                options.add_argument("--disable-gpu")
                options.add_argument("--no-sandbox")
                options.add_argument("--disable-dev-shm-usage")
                
                driver = webdriver.Chrome(options=options)
                driver.get("https://httpbin.org/html")
                title = driver.title
                driver.quit()
                
                self.log_message("✅ Selenium功能正常")
            except Exception as e:
                self.log_message(f"❌ Selenium功能异常: {str(e)}")
                return False
            
            self.log_message("✅ 所有基础功能测试通过")
            return True
            
        except Exception as e:
            self.log_message(f"❌ 基础功能测试失败: {str(e)}")
            return False
    
    def access_target_website(self):
        """访问目标网站"""
        try:
            from selenium import webdriver
            from selenium.webdriver.chrome.options import Options
            from selenium.webdriver.common.by import By
            from selenium.webdriver.support.ui import WebDriverWait
            from selenium.webdriver.support import expected_conditions as EC
            
            self.log_message(f"🌐 开始访问目标网站 {self.target_url} ...")
            
            options = Options()
            options.add_argument("--disable-blink-features=AutomationControlled")
            options.add_experimental_option("excludeSwitches", ["enable-automation"])
            options.add_experimental_option('useAutomationExtension', False)
            options.add_argument("--window-size=1920,1080")
            
            driver = webdriver.Chrome(options=options)
            driver.execute_script("Object.defineProperty(navigator, 'webdriver', {get: () => undefined})")
            
            # 访问目标网站
            driver.get(self.target_url)
            
            # 等待页面加载
            WebDriverWait(driver, 15).until(
                EC.presence_of_element_located((By.TAG_NAME, "body"))
            )
            
            self.log_message("✅ 页面加载成功")
            
            # 获取页面信息
            page_title = driver.title
            page_url = driver.current_url
            page_source = driver.page_source
            
            self.log_message(f"📄 页面标题: {page_title}")
            self.log_message(f"🔗 页面URL: {page_url}")
            self.log_message(f"📏 页面大小: {len(page_source)} 字节")
            
            # 分析页面结构
            soup = BeautifulSoup(page_source, 'html.parser')
            
            # 查找导航栏和分类
            nav_elements = soup.find_all(['nav', 'div'], class_=re.compile(r'nav|menu|categor', re.I))
            categories = []
            
            for nav in nav_elements:
                links = nav.find_all('a', href=True)
                for link in links:
                    href = link.get('href', '')
                    text = link.get_text(strip=True)
                    if href and text and len(text) > 1 and len(text) < 50:
                        categories.append({
                            'name': text,
                            'url': href if href.startswith('http') else urljoin(self.target_url, href),
                            'element': str(link)[:100] + "..."
                        })
            
            self.log_message(f"📂 找到 {len(categories)} 个可能的分类")
            
            # 查找视频链接
            video_links = []
            video_selectors = [
                "a[href*='/videos/']",
                "a[href*='/video/']",
                ".video-item a",
                ".post a"
            ]
            
            for selector in video_selectors:
                links = soup.select(selector)
                for link in links:
                    href = link.get('href')
                    if href and '/videos/' in href:
                        full_url = href if href.startswith('http') else urljoin(self.target_url, href)
                        if full_url not in video_links:
                            video_links.append(full_url)
            
            self.log_message(f"🎬 找到 {len(video_links)} 个视频链接")
            
            driver.quit()
            
            self.analysis_result['categories'] = categories
            self.analysis_result['video_links'] = video_links
            self.analysis_result['page_title'] = page_title
            self.analysis_result['page_url'] = page_url
            
            # 显示分析结果
            self.display_analysis_result()
            
            return True
                
        except Exception as e:
            self.log_message(f"❌ 访问目标网站失败: {str(e)}")
            return False
    
    def deep_analyze_website(self):
        """深度分析网站结构"""
        self.log_message("🔍 开始深度分析网站结构...")
        
        try:
            from selenium import webdriver
            from selenium.webdriver.chrome.options import Options
            from selenium.webdriver.common.by import By
            from selenium.webdriver.support.ui import WebDriverWait
            from selenium.webdriver.support import expected_conditions as EC
            
            options = Options()
            options.add_argument("--disable-blink-features=AutomationControlled")
            options.add_experimental_option("excludeSwitches", ["enable-automation"])
            options.add_experimental_option('useAutomationExtension', False)
            
            driver = webdriver.Chrome(options=options)
            driver.execute_script("Object.defineProperty(navigator, 'webdriver', {get: () => undefined})")
            
            driver.get(self.target_url)
            WebDriverWait(driver, 10).until(
                EC.presence_of_element_located((By.TAG_NAME, "body"))
            )
            
            # 分析网站技术栈
            page_source = driver.page_source
            soup = BeautifulSoup(page_source, 'html.parser')
            
            # 检测JavaScript框架
            scripts = soup.find_all('script', src=True)
            js_frameworks = []
            for script in scripts:
                src = script['src']
                if 'jquery' in src.lower():
                    js_frameworks.append('jQuery')
                elif 'react' in src.lower():
                    js_frameworks.append('React')
                elif 'vue' in src.lower():
                    js_frameworks.append('Vue')
                elif 'angular' in src.lower():
                    js_frameworks.append('Angular')
            
            # 检测CSS框架
            css_links = soup.find_all('link', rel='stylesheet')
            css_frameworks = []
            for link in css_links:
                href = link.get('href', '')
                if 'bootstrap' in href.lower():
                    css_frameworks.append('Bootstrap')
                elif 'foundation' in href.lower():
                    css_frameworks.append('Foundation')
                elif 'bulma' in href.lower():
                    css_frameworks.append('Bulma')
            
            # 分析视频播放方式
            video_elements = driver.find_elements(By.TAG_NAME, "video")
            iframe_elements = driver.find_elements(By.TAG_NAME, "iframe")
            
            # 分析分页结构
            pagination_elements = driver.find_elements(By.CSS_SELECTOR, "[class*='pagination'], [class*='page']")
            
            # 分析AJAX加载
            network_requests = driver.execute_script("""
                return window.performance.getEntriesByType("resource").map(function(r) {
                    return {
                        name: r.name,
                        type: r.initiatorType,
                        size: r.transferSize
                    };
                });
            """)
            
            ajax_requests = [r for r in network_requests if r['type'] == 'xmlhttprequest']
            
            analysis_result = {
                "technology_stack": {
                    "javascript_frameworks": list(set(js_frameworks)),
                    "css_frameworks": list(set(css_frameworks))
                },
                "content_loading": {
                    "video_elements": len(video_elements),
                    "iframe_elements": len(iframe_elements),
                    "ajax_requests": len(ajax_requests)
                },
                "pagination": {
                    "has_pagination": len(pagination_elements) > 0,
                    "pagination_elements": len(pagination_elements)
                },
                "anti_crawler": {
                    "has_cloudflare": "cloudflare" in page_source.lower(),
                    "has_recaptcha": "recaptcha" in page_source.lower(),
                    "has_anti_bot": any(keyword in page_source.lower() for keyword in ['bot', 'crawler', 'spider'])
                }
            }
            
            driver.quit()
            
            # 更新分析结果
            self.analysis_result.update(analysis_result)
            
            self.log_message("✅ 深度分析完成")
            return True
            
        except Exception as e:
            self.log_message(f"❌ 深度分析失败: {str(e)}")
            return False
    
    def display_analysis_result(self):
        """显示分析结果"""
        self.analysis_text.delete(1.0, tk.END)
        
        if not self.analysis_result:
            self.analysis_text.insert(tk.END, "暂无分析结果，请先运行网站分析")
            return
        
        # 显示分析结果
        self.analysis_text.insert(tk.END, "=== 网站分析结果 ===\n\n")
        
        self.analysis_text.insert(tk.END, f"页面标题: {self.analysis_result.get('page_title', '未知')}\n")
        self.analysis_text.insert(tk.END, f"页面URL: {self.analysis_result.get('page_url', '未知')}\n")
        
        # 技术栈信息
        if 'technology_stack' in self.analysis_result:
            tech = self.analysis_result['technology_stack']
            self.analysis_text.insert(tk.END, f"JavaScript框架: {', '.join(tech.get('javascript_frameworks', [])) or '未检测到'}\n")
            self.analysis_text.insert(tk.END, f"CSS框架: {', '.join(tech.get('css_frameworks', [])) or '未检测到'}\n")
        
        # 内容加载方式
        if 'content_loading' in self.analysis_result:
            content = self.analysis_result['content_loading']
            self.analysis_text.insert(tk.END, f"视频元素: {content.get('video_elements', 0)}\n")
            self.analysis_text.insert(tk.END, f"iframe元素: {content.get('iframe_elements', 0)}\n")
            self.analysis_text.insert(tk.END, f"AJAX请求: {content.get('ajax_requests', 0)}\n")
        
        # 分类信息
        if 'categories' in self.analysis_result:
            categories = self.analysis_result['categories']
            self.analysis_text.insert(tk.END, f"检测到分类: {len(categories)} 个\n")
            for i, cat in enumerate(categories[:8]):
                self.analysis_text.insert(tk.END, f"  {i+1}. {cat.get('name', '未知')}\n")
            if len(categories) > 8:
                self.analysis_text.insert(tk.END, f"  ... 还有 {len(categories)-8} 个分类\n")
        
        # 视频链接
        if 'video_links' in self.analysis_result:
            video_links = self.analysis_result['video_links']
            self.analysis_text.insert(tk.END, f"视频链接数量: {len(video_links)} 个\n")
    
    def generate_analysis_report(self):
        """生成分析报告"""
        report = {
            "generated_at": time.strftime("%Y-%m-%d %H:%M:%S"),
            "target_website": self.target_url,
            "analysis_result": self.analysis_result,
            "system_info": {
                "platform": platform.platform(),
                "python_version": platform.python_version(),
                "required_packages": self.required_packages
            }
        }
        
        # 保存报告
        with open("website_analysis_report.json", "w", encoding="utf-8") as f:
            json.dump(report, f, indent=2, ensure_ascii=False)
        
        self.log_message("📄 分析报告已保存到 website_analysis_report.json")
    
    def start_media_sniffing(self):
        """开始多媒体嗅探"""
        if self.sniffing_in_progress:
            return
        
        if not self.analysis_result.get('video_links'):
            self.log_message("❌ 没有找到视频链接，请先运行智能分析")
            return
        
        self.sniffing_in_progress = True
        self.start_sniff_button.config(state=tk.DISABLED)
        self.stop_sniff_button.config(state=tk.NORMAL)
        
        # 更新嗅探器配置
        self.media_sniffer.max_workers = int(self.sniff_threads_var.get())
        
        # 在新线程中运行嗅探
        thread = threading.Thread(target=self.media_sniffing_process)
        thread.daemon = True
        thread.start()
    
    def media_sniffing_process(self):
        """多媒体嗅探过程"""
        try:
            video_links = self.analysis_result.get('video_links', [])
            total_videos = len(video_links)
            
            self.log_message(f"🎯 开始多媒体嗅探，共 {total_videos} 个视频")
            self.log_message(f"🔧 嗅探配置: {self.media_sniffer.max_workers}线程, {self.sniff_type_var.get()}")
            
            # 批量嗅探视频
            self.media_sniffer.batch_sniff_videos(
                video_links, 
                callback=self.update_sniff_progress
            )
            
            # 更新嗅探数据
            self.sniffed_data = self.media_sniffer.sniffed_data
            
            # 显示嗅探结果
            successful_sniffs = len(self.sniffed_data)
            self.log_message(f"✅ 多媒体嗅探完成! 成功: {successful_sniffs}/{total_videos}")
            
            # 更新统计信息
            self.update_sniff_stats()
            
            # 自动启动智能小扒手
            self.log_message("🤖 嗅探完成，准备启动智能小扒手...")
            self.root.after(2000, self.launch_smart_crawler)
            
        except Exception as e:
            self.log_message(f"❌ 多媒体嗅探失败: {str(e)}")
        
        self.sniffing_in_progress = False
        self.start_sniff_button.config(state=tk.NORMAL)
        self.stop_sniff_button.config(state=tk.DISABLED)
    
    def update_sniff_progress(self, completed, total, message):
        """更新嗅探进度"""
        self.stats_label.config(text=f"📈 嗅探进度: {completed}/{total}")
        self.log_message(f"🔍 {message}")
        self.root.update_idletasks()
    
    def update_sniff_stats(self):
        """更新嗅探统计信息"""
        total_videos = len(self.analysis_result.get('video_links', []))
        successful_sniffs = len(self.sniffed_data)
        
        # 统计各种媒体类型
        video_count = 0
        audio_count = 0
        image_count = 0
        magnet_count = 0
        
        for data in self.sniffed_data.values():
            video_count += len(data.get('video_links', []))
            audio_count += len(data.get('audio_links', []))
            image_count += len(data.get('image_links', []))
            magnet_count += len(data.get('magnet_links', []))
        
        stats_text = f"📊 嗅探统计: 成功{successful_sniffs}/{total_videos} | 视频:{video_count} | 音频:{audio_count} | 图片:{image_count} | 磁力:{magnet_count}"
        self.stats_label.config(text=stats_text)
        
        # 在分析结果中显示嗅探统计
        self.analysis_text.insert(tk.END, f"\n=== 多媒体嗅探结果 ===\n")
        self.analysis_text.insert(tk.END, f"成功嗅探: {successful_sniffs}/{total_videos} 个视频\n")
        self.analysis_text.insert(tk.END, f"发现视频链接: {video_count} 个\n")
        self.analysis_text.insert(tk.END, f"发现音频链接: {audio_count} 个\n")
        self.analysis_text.insert(tk.END, f"发现图片链接: {image_count} 个\n")
        self.analysis_text.insert(tk.END, f"发现磁力链接: {magnet_count} 个\n")
    
    def stop_media_sniffing(self):
        """停止多媒体嗅探"""
        self.sniffing_in_progress = False
        self.start_sniff_button.config(state=tk.NORMAL)
        self.stop_sniff_button.config(state=tk.DISABLED)
        self.log_message("🟡 正在停止多媒体嗅探...")
    
    def launch_smart_crawler(self):
        """启动智能小扒手"""
        try:
            # 启动智能小扒手GUI，传递智库数据
            crawler_gui = SmartCrawlerGUI(self.root, self.analysis_result, self.target_url, self)
            self.log_message("🤖 智能小扒手已启动 - 使用智库数据进行深度爬取")
            
        except Exception as e:
            self.log_message(f"❌ 启动智能小扒手失败: {str(e)}")
    
    def start_auto_mode(self):
        """启动全自动模式"""
        self.log_message("🚀 启动全自动模式: 分析 → 嗅探 → 爬取")
        self.start_smart_analysis()
    
    def auto_repair(self):
        """自动修复"""
        self.log_message("🔧 开始自动修复...")
        
        # 在新线程中运行修复过程
        thread = threading.Thread(target=self.repair_process)
        thread.daemon = True
        thread.start()
    
    def repair_process(self):
        """修复过程"""
        try:
            # 重新安装所有包
            self.log_message("📦 重新安装所有必需的包...")
            for package in self.required_packages:
                try:
                    subprocess.check_call([sys.executable, "-m", "pip", "install", "--upgrade", "--force-reinstall", package])
                    self.log_message(f"✅ {package} 重新安装成功")
                except subprocess.CalledProcessError as e:
                    self.log_message(f"❌ {package} 重新安装失败: {e}")
            
            self.log_message("✅ 自动修复完成!")
            
        except Exception as e:
            self.log_message(f"❌ 自动修复失败: {str(e)}")

# ==================== 智能小扒手GUI ====================
class SmartCrawlerGUI:
    """智能小扒手GUI程序 - 增强版本"""
    def __init__(self, parent, analysis_result=None, target_url=None, knowledge_base=None):
        self.parent = parent
        self.analysis_result = analysis_result or {}
        self.target_url = target_url
        self.knowledge_base = knowledge_base  # 智库引用
        self.crawler = None
        self.crawling = False
        
        self.create_widgets()
        self.load_analysis_result()
    
    def create_widgets(self):
        """创建增强后的GUI组件"""
        self.window = tk.Toplevel(self.parent)
        self.window.title("🤖 智能小扒手 - 视频爬虫控制中心")
        self.window.geometry("1000x800")
        self.window.configure(bg='#2c3e50')
        
        # 设置样式
        self.setup_styles()
        
        # 主框架
        main_frame = ttk.Frame(self.window, padding="15", style='Custom.TFrame')
        main_frame.grid(row=0, column=0, sticky=(tk.W, tk.E, tk.N, tk.S))
        
        # 标题
        title_label = ttk.Label(main_frame, text="🤖 智能小扒手 - 视频爬虫控制中心", 
                               font=("Microsoft YaHei", 18, "bold"), style='Title.TLabel')
        title_label.grid(row=0, column=0, columnspan=2, pady=(0, 20))
        
        # 数据来源显示
        source_frame = ttk.LabelFrame(main_frame, text="🧠 数据来源", padding="10", style='Custom.TLabelframe')
        source_frame.grid(row=1, column=0, columnspan=2, sticky=(tk.W, tk.E), pady=(0, 10))
        
        source_text = "智库深度分析 + 多媒体嗅探" if self.knowledge_base else "实时分析"
        source_label = ttk.Label(source_frame, text=f"数据来源: {source_text}", style='Custom.TLabel')
        source_label.grid(row=0, column=0, sticky=tk.W)
        
        if self.knowledge_base and hasattr(self.knowledge_base, 'sniffed_data'):
            sniffed_count = len(self.knowledge_base.sniffed_data)
            total_count = len(self.analysis_result.get('video_links', []))
            sniff_label = ttk.Label(source_frame, text=f"嗅探数据: {sniffed_count}/{total_count} 个视频已预处理", style='Custom.TLabel')
            sniff_label.grid(row=0, column=1, sticky=tk.W, padx=(20, 0))
        
        # 目标网站显示
        url_frame = ttk.LabelFrame(main_frame, text="🌐 目标网站", padding="10", style='Custom.TLabelframe')
        url_frame.grid(row=2, column=0, columnspan=2, sticky=(tk.W, tk.E), pady=(0, 10))
        
        url_label = ttk.Label(url_frame, text=f"目标网址: {self.target_url}", style='Custom.TLabel')
        url_label.grid(row=0, column=0, sticky=tk.W)
        
        # 网站分析结果显示
        analysis_frame = ttk.LabelFrame(main_frame, text="📊 网站分析结果", padding="10", style='Custom.TLabelframe')
        analysis_frame.grid(row=3, column=0, columnspan=2, sticky=(tk.W, tk.E), pady=(0, 10))
        
        self.analysis_text = scrolledtext.ScrolledText(analysis_frame, height=8, bg='#ecf0f1', fg='#2c3e50',
                                                     font=("Consolas", 10))
        self.analysis_text.grid(row=0, column=0, sticky=(tk.W, tk.E, tk.N, tk.S))
        
        # 爬虫控制框架
        control_frame = ttk.LabelFrame(main_frame, text="🎮 爬虫控制", padding="10", style='Custom.TLabelframe')
        control_frame.grid(row=4, column=0, columnspan=2, sticky=(tk.W, tk.E), pady=(0, 10))
        
        # 配置选项
        config_frame = ttk.Frame(control_frame, style='Custom.TFrame')
        config_frame.grid(row=0, column=0, columnspan=2, sticky=(tk.W, tk.E), pady=(0, 10))
        
        ttk.Label(config_frame, text="🚀 线程数:", style='Custom.TLabel').grid(row=0, column=0, sticky=tk.W)
        self.thread_var = tk.StringVar(value="18")
        thread_combo = ttk.Combobox(config_frame, textvariable=self.thread_var, 
                                   values=["1", "5", "10", "18", "25", "50"], width=10, style='Custom.TCombobox')
        thread_combo.grid(row=0, column=1, padx=(5, 20), sticky=tk.W)
        
        ttk.Label(config_frame, text="📁 保存路径:", style='Custom.TLabel').grid(row=0, column=2, sticky=tk.W)
        self.path_var = tk.StringVar(value="jabletv")
        path_entry = ttk.Entry(config_frame, textvariable=self.path_var, width=25, style='Custom.TEntry')
        path_entry.grid(row=0, column=3, padx=(5, 10), sticky=tk.W)
        ttk.Button(config_frame, text="浏览", command=self.browse_path, style='Action.TButton').grid(row=0, column=4, padx=(5, 0))
        
        # 控制按钮
        button_frame = ttk.Frame(control_frame, style='Custom.TFrame')
        button_frame.grid(row=1, column=0, columnspan=2, pady=15)
        
        self.start_button = ttk.Button(button_frame, text="🚀 开始全站爬取", 
                                      command=self.start_crawling, style='Accent.TButton')
        self.start_button.grid(row=0, column=0, padx=(0, 10))
        
        self.stop_button = ttk.Button(button_frame, text="⏹️ 停止爬取", 
                                     command=self.stop_crawling, state=tk.DISABLED, style='Warning.TButton')
        self.stop_button.grid(row=0, column=1, padx=(0, 10))
        
        self.open_folder_button = ttk.Button(button_frame, text="📂 打开结果文件夹", 
                                           command=self.open_result_folder, style='Action.TButton')
        self.open_folder_button.grid(row=0, column=2, padx=(0, 10))
        
        # 进度显示
        progress_frame = ttk.Frame(control_frame, style='Custom.TFrame')
        progress_frame.grid(row=2, column=0, columnspan=2, sticky=(tk.W, tk.E), pady=(10, 0))
        
        self.progress_label = ttk.Label(progress_frame, text="🟢 准备就绪", style='Custom.TLabel')
        self.progress_label.grid(row=0, column=0, sticky=tk.W)
        
        self.progress_bar = ttk.Progressbar(progress_frame, mode='determinate', style='Custom.Horizontal.TProgressbar')
        self.progress_bar.grid(row=1, column=0, sticky=(tk.W, tk.E), pady=(5, 0))
        
        # 统计信息
        stats_frame = ttk.Frame(control_frame, style='Custom.TFrame')
        stats_frame.grid(row=3, column=0, columnspan=2, sticky=(tk.W, tk.E), pady=(10, 0))
        
        self.stats_label = ttk.Label(stats_frame, text="📈 统计: 等待开始...", style='Custom.TLabel')
        self.stats_label.grid(row=0, column=0, sticky=tk.W)
        
        # 实时数据展示
        data_frame = ttk.Frame(control_frame, style='Custom.TFrame')
        data_frame.grid(row=4, column=0, columnspan=2, sticky=(tk.W, tk.E), pady=(10, 0))
        
        self.data_label = ttk.Label(data_frame, text="📊 实时数据: 等待爬取...", style='Custom.TLabel')
        self.data_label.grid(row=0, column=0, sticky=tk.W)
        
        # 日志输出
        log_frame = ttk.LabelFrame(main_frame, text="📝 爬虫日志", padding="10", style='Custom.TLabelframe')
        log_frame.grid(row=5, column=0, columnspan=2, sticky=(tk.W, tk.E, tk.N, tk.S), pady=(10, 0))
        
        self.log_text = scrolledtext.ScrolledText(log_frame, height=15, bg='#1a1a1a', fg='#00ff00',
                                                font=("Consolas", 9))
        self.log_text.grid(row=0, column=0, sticky=(tk.W, tk.E, tk.N, tk.S))
        
        # 配置网格权重
        self.window.columnconfigure(0, weight=1)
        self.window.rowconfigure(0, weight=1)
        main_frame.columnconfigure(0, weight=1)
        main_frame.rowconfigure(5, weight=1)
        log_frame.columnconfigure(0, weight=1)
        log_frame.rowconfigure(0, weight=1)
        analysis_frame.columnconfigure(0, weight=1)
        analysis_frame.rowconfigure(0, weight=1)
        control_frame.columnconfigure(0, weight=1)
        progress_frame.columnconfigure(0, weight=1)
        stats_frame.columnconfigure(0, weight=1)
        data_frame.columnconfigure(0, weight=1)
        
        # 自动开始爬取
        self.window.after(2000, self.start_crawling)
    
    def setup_styles(self):
        """设置美化样式"""
        style = ttk.Style()
        
        # 配置样式
        style.configure('Custom.TFrame', background='#34495e')
        style.configure('Custom.TLabelframe', background='#34495e', foreground='white')
        style.configure('Custom.TLabel', background='#34495e', foreground='white', font=('Microsoft YaHei', 10))
        style.configure('Title.TLabel', background='#34495e', foreground='#e74c3c', font=('Microsoft YaHei', 18, 'bold'))
        style.configure('Accent.TButton', background='#27ae60', foreground='white', font=('Microsoft YaHei', 10, 'bold'))
        style.configure('Action.TButton', background='#3498db', foreground='white', font=('Microsoft YaHei', 10))
        style.configure('Warning.TButton', background='#e74c3c', foreground='white', font=('Microsoft YaHei', 10))
        style.configure('Custom.TCombobox', background='white')
        style.configure('Custom.TEntry', background='white')
        style.configure('Custom.Horizontal.TProgressbar', background='#27ae60')
    
    def load_analysis_result(self):
        """加载分析结果"""
        if not self.analysis_result:
            self.analysis_text.insert(tk.END, "暂无分析结果")
            return
        
        # 显示分析结果
        self.analysis_text.insert(tk.END, "=== 智库分析结果 ===\n\n")
        
        self.analysis_text.insert(tk.END, f"页面标题: {self.analysis_result.get('page_title', '未知')}\n")
        self.analysis_text.insert(tk.END, f"页面URL: {self.analysis_result.get('page_url', '未知')}\n")
        
        # 分类信息
        if 'categories' in self.analysis_result:
            categories = self.analysis_result['categories']
            self.analysis_text.insert(tk.END, f"检测到分类: {len(categories)} 个\n")
            for i, cat in enumerate(categories[:8]):
                self.analysis_text.insert(tk.END, f"  {i+1}. {cat.get('name', '未知')}\n")
        
        # 视频链接
        if 'video_links' in self.analysis_result:
            video_links = self.analysis_result['video_links']
            self.analysis_text.insert(tk.END, f"视频链接数量: {len(video_links)} 个\n")
        
        # 嗅探数据
        if self.knowledge_base and hasattr(self.knowledge_base, 'sniffed_data'):
            sniffed_count = len(self.knowledge_base.sniffed_data)
            total_count = len(video_links) if 'video_links' in self.analysis_result else 0
            self.analysis_text.insert(tk.END, f"多媒体嗅探: {sniffed_count}/{total_count} 个视频已预处理\n")
    
    def browse_path(self):
        """浏览选择保存路径"""
        path = filedialog.askdirectory()
        if path:
            self.path_var.set(path)
    
    def log_message(self, message):
        """在日志区域添加消息"""
        self.log_text.insert(tk.END, f"{time.strftime('%H:%M:%S')} - {message}\n")
        self.log_text.see(tk.END)
        self.window.update_idletasks()
    
    def update_progress(self, current, total, message):
        """更新进度"""
        if total > 0:
            progress = (current / total) * 100
            self.progress_bar['value'] = progress
        self.progress_label.config(text=message)
        self.stats_label.config(text=f"📈 统计: 已完成 {current}/{total} | {message}")
        self.window.update_idletasks()
    
    def update_data_display(self, videos_count, categories_count, current_category):
        """更新实时数据展示"""
        data_text = f"📊 实时数据: 视频{videos_count}个 | 分类{categories_count}个 | 当前:{current_category}"
        self.data_label.config(text=data_text)
        self.window.update_idletasks()
    
    def start_crawling(self):
        """开始爬取"""
        if self.crawling:
            return
        
        self.crawling = True
        self.start_button.config(state=tk.DISABLED)
        self.stop_button.config(state=tk.NORMAL)
        
        # 在新线程中运行爬虫
        thread = threading.Thread(target=self.crawling_process)
        thread.daemon = True
        thread.start()
    
    def stop_crawling(self):
        """停止爬取"""
        self.crawling = False
        self.start_button.config(state=tk.NORMAL)
        self.stop_button.config(state=tk.DISABLED)
        self.log_message("🟡 正在停止爬虫...")
    
    def crawling_process(self):
        """爬虫过程"""
        try:
            self.log_message("🚀 初始化爬虫引擎...")
            
            # 创建爬虫实例
            max_workers = int(self.thread_var.get())
            
            self.log_message(f"🔧 配置参数: {max_workers}线程")
            self.log_message(f"🌐 目标网站: {self.target_url}")
            self.log_message(f"🧠 数据来源: {'智库深度分析' if self.knowledge_base else '实时分析'}")
            
            self.crawler = JableTVCrawler(
                max_workers=max_workers, 
                headless=True, 
                target_url=self.target_url,
                knowledge_base=self.knowledge_base
            )
            
            # 设置自定义保存路径
            if self.path_var.get() != "jabletv":
                self.crawler.base_dir = self.path_var.get()
                if not os.path.exists(self.crawler.base_dir):
                    os.makedirs(self.crawler.base_dir)
            
            self.log_message(f"📁 结果保存到: {self.crawler.base_dir}")
            
            # 开始爬取
            report = self.crawler.crawl_all(progress_callback=self.handle_progress_update)
            
            if self.crawling:
                self.log_message("✅ 爬取完成!")
                self.log_message(f"📊 总计爬取: {report['total_videos']} 个视频")
                self.log_message(f"📂 分类数量: {report['total_categories']} 个")
                self.log_message(f"⏱️ 耗时: {report['elapsed_seconds']} 秒")
                
                # 显示完成消息
                messagebox.showinfo("爬取完成", 
                                  f"爬取完成!\\n"
                                  f"视频数量: {report['total_videos']}\\n"
                                  f"分类数量: {report['total_categories']}\\n"
                                  f"耗时: {report['elapsed_seconds']}秒")
            else:
                self.log_message("🟡 爬取被用户中断")
            
        except Exception as e:
            self.log_message(f"❌ 爬取过程中出现错误: {str(e)}")
            messagebox.showerror("错误", f"爬取过程中出现错误: {str(e)}")
        
        finally:
            self.crawling = False
            self.start_button.config(state=tk.NORMAL)
            self.stop_button.config(state=tk.DISABLED)
            self.progress_bar['value'] = 0
            self.progress_label.config(text="🟢 爬取完成")
            self.stats_label.config(text="📈 统计: 任务完成")
    
    def handle_progress_update(self, count, message):
        """处理进度更新"""
        self.log_message(f"📈 {message}")
        self.update_data_display(count, len(self.crawler.categories) if self.crawler else 0, "处理中")
        self.window.update_idletasks()
    
    def open_result_folder(self):
        """打开结果文件夹"""
        path = self.path_var.get()
        if os.path.exists(path):
            if platform.system() == "Windows":
                os.startfile(path)
            elif platform.system() == "Darwin":  # macOS
                subprocess.Popen(["open", path])
            else:  # Linux
                subprocess.Popen(["xdg-open", path])
        else:
            messagebox.showwarning("警告", "结果文件夹不存在")

# ==================== 主函数 ====================
def main():
    """主函数"""
    root = tk.Tk()
    app = KnowledgeBase(root)
    root.mainloop()

if __name__ == "__main__":
    main()