from abc import ABC, abstractmethod
from selenium import webdriver
from selenium.webdriver.chrome.service import Service
from selenium.webdriver.common.by import By
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
from selenium.webdriver.chrome.options import Options
from selenium.common.exceptions import InvalidArgumentException, WebDriverException
from PIL import Image, ImageDraw, ImageFont
from io import BytesIO
from typing import List, Callable
import logging
import time
import base64
import requests
import os
from pathlib import Path
from .config import *
from .utils import *

# Configure logging
logging.getLogger('selenium.webdriver.remote.remote_connection').setLevel(logging.WARNING)
logging.getLogger('selenium.webdriver.common.service').setLevel(logging.WARNING)
logging.getLogger('urllib3.connectionpool').setLevel(logging.WARNING)
logging.getLogger('http.client').setLevel(logging.WARNING)
logging.getLogger('selenium.webdriver.common.driver_finder').setLevel(logging.WARNING)

class CrawlerStrategy(ABC):
    @abstractmethod
    def crawl(self, url: str, **kwargs) -> str:
        pass
    
    @abstractmethod
    def take_screenshot(self) -> str:
        pass
    
    @abstractmethod
    def update_user_agent(self, user_agent: str):
        pass
    
    @abstractmethod
    def set_hook(self, hook_type: str, hook: Callable):
        pass

class CloudCrawlerStrategy(CrawlerStrategy):
    def __init__(self, use_cached_html=False):
        self.use_cached_html = use_cached_html
        
    def crawl(self, url: str) -> str:
        data = {
            "urls": [url],
            "include_raw_html": True,
            "forced": True,
            "extract_blocks": False,
        }
        response = requests.post("http://crawl4ai.uccode.io/crawl", json=data).json()
        html = response["results"][0]["html"]
        return sanitize_input_encode(html)

class LocalSeleniumCrawlerStrategy(CrawlerStrategy):
    def __init__(self, use_cached_html=False, js_code=None, **kwargs):
        self.options = self._initialize_options(kwargs)
        self.use_cached_html = use_cached_html
        self.js_code = js_code
        self.verbose = kwargs.get("verbose", False)
        
        # Hooks
        self.hooks = {
            'on_driver_created': None,
            'on_user_agent_updated': None,
            'before_get_url': None,
            'after_get_url': None,
            'before_return_html': None
        }

        self.service = Service()
        self.driver = webdriver.Chrome(options=self.options)
        self.driver = self._execute_hook('on_driver_created', self.driver)

        if kwargs.get("cookies"):
            for cookie in kwargs.get("cookies"):
                self.driver.add_cookie(cookie)

    def _initialize_options(self, kwargs):
        options = Options()
        options.headless = kwargs.get("headless", True)
        options.add_argument("--disable-gpu")
        options.add_argument("--window-size=1920,1080")
        options.add_argument("--no-sandbox")
        options.add_argument("--disable-dev-shm-usage")
        options.add_argument("--disable-blink-features=AutomationControlled")
        options.add_argument("--log-level=3")
        
        user_agent = kwargs.get("user_agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36")
        options.add_argument(f"user-agent={user_agent}")
        
        return options

    def set_hook(self, hook_type: str, hook: Callable):
        if hook_type in self.hooks:
            self.hooks[hook_type] = hook
        else:
            raise ValueError(f"Invalid hook type: {hook_type}")
    
    def _execute_hook(self, hook_type: str, *args):
        hook = self.hooks.get(hook_type)
        if hook:
            result = hook(*args)
            if isinstance(result, webdriver.Chrome):
                return result
        return self.driver

    def update_user_agent(self, user_agent: str):
        self.options.add_argument(f"user-agent={user_agent}")
        self.driver.quit()
        self.driver = webdriver.Chrome(service=self.service, options=self.options)
        self.driver = self._execute_hook('on_user_agent_updated', self.driver)

    def set_custom_headers(self, headers: dict):
        self.driver.execute_cdp_cmd('Network.enable', {})
        self.driver.execute_cdp_cmd('Network.setExtraHTTPHeaders', {'headers': headers})

    def _ensure_page_load(self, max_checks=6, check_interval=0.01):
        initial_length = len(self.driver.page_source)
        for _ in range(max_checks):
            time.sleep(check_interval)
            current_length = len(self.driver.page_source)
            if current_length != initial_length:
                break
        return self.driver.page_source
    
    def crawl(self, url: str, **kwargs) -> str:
        url_hash = hashlib.md5(url.encode()).hexdigest()
        cache_file_path = os.path.join(Path.home(), ".crawl4ai", "cache", url_hash)

        if self.use_cached_html and os.path.exists(cache_file_path):
            with open(cache_file_path, "r") as f:
                return sanitize_input_encode(f.read())

        try:
            self.driver = self._execute_hook('before_get_url', self.driver)
            if self.verbose:
                print(f"[LOG] 🕸️ Crawling {url} using LocalSeleniumCrawlerStrategy...")
            self.driver.get(url)
            
            WebDriverWait(self.driver, 20).until(
                lambda d: d.execute_script('return document.readyState') == 'complete'
            )
            WebDriverWait(self.driver, 10).until(
                EC.presence_of_all_elements_located((By.TAG_NAME, "body"))
            )
            
            self.driver.execute_script("window.scrollTo(0, document.body.scrollHeight);")
            self.driver = self._execute_hook('after_get_url', self.driver)
            html = sanitize_input_encode(self._ensure_page_load())
            
            if kwargs.get('bypass_headless', False) or html == "<html><head></head><body></body></html>":
                html = self._handle_non_headless(url)

            self._execute_js_code()
            
            with open(cache_file_path, "w", encoding="utf-8") as f:
                f.write(html)
                
            if self.verbose:
                print(f"[LOG] ✅ Crawled {url} successfully!")
            
            return html
        except (InvalidArgumentException, WebDriverException) as e:
            raise WebDriverException(f"Failed to crawl {url}: {e.msg}")  
        except Exception as e:
            raise Exception(f"Failed to crawl {url}: {str(e)}")

    def _handle_non_headless(self, url):
        options = Options()
        options.headless = False
        options.add_argument("--window-size=5,5")
        driver = webdriver.Chrome(service=self.service, options=options)
        driver.get(url)
        html = sanitize_input_encode(driver.page_source)
        driver.quit()
        return html

    def _execute_js_code(self):
        if self.js_code:
            scripts = [self.js_code] if isinstance(self.js_code, str) else self.js_code
            for js in scripts:
                self.driver.execute_script(js)
                WebDriverWait(self.driver, 10).until(
                    lambda driver: driver.execute_script("return document.readyState") == "complete"
                )

    def take_screenshot(self) -> str:
        try:
            total_width = self.driver.execute_script("return document.body.scrollWidth")
            total_height = self.driver.execute_script("return document.body.scrollHeight")
            self.driver.set_window_size(total_width, total_height)
            screenshot = self.driver.get_screenshot_as_png()

            image = Image.open(BytesIO(screenshot)).convert('RGB')
            buffered = BytesIO()
            image.save(buffered, format="JPEG", quality=85)
            img_base64 = base64.b64encode(buffered.getvalue()).decode('utf-8')

            if self.verbose:
                print(f"[LOG] 📸 Screenshot taken and converted to base64")

            return img_base64
        except Exception as e:
            return self._generate_error_image(str(e))
        
    def _generate_error_image(self, error_message: str) -> str:
        img = Image.new('RGB', (800, 600), color='black')
        draw = ImageDraw.Draw(img)
        font = ImageFont.truetype("arial.ttf", 40) if os.path.exists("arial.ttf") else ImageFont.load_default()
        wrapped_text = wrap_text(draw, sanitize_input_encode(error_message), font, max_width=780)
        draw.text((10, 10), wrapped_text, fill=(255, 255, 255), font=font)
        buffered = BytesIO()
        img.save(buffered, format="JPEG")
        return base64.b64encode(buffered.getvalue()).decode('utf-8')
        
    def quit(self):
        self.driver.quit()
