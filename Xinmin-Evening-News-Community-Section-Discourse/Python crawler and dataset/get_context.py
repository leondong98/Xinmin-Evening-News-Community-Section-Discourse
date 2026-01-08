import csv
import re
import time
from math import ceil

import requests
from lxml import etree

cookies = {
    'HMACCOUNT': 'CC5AE7EC56D6DB25',
    'Hm_lpvt_8ab7263c9280868f0c3ef17366bf585a': str(ceil(time.time())),
}

headers = {
    'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.7',
    'Accept-Language': 'zh-CN,zh;q=0.9',
    'Cache-Control': 'no-cache',
    'Connection': 'keep-alive',
    'Pragma': 'no-cache',
    'Referer': 'https://xmwb.xinmin.cn/xmwbzone/html/2018-12/12/node_2.htm',
    'Sec-Fetch-Dest': 'document',
    'Sec-Fetch-Mode': 'navigate',
    'Sec-Fetch-Site': 'same-origin',
    'Sec-Fetch-User': '?1',
    'Upgrade-Insecure-Requests': '1',
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/141.0.0.0 Safari/537.36',
    'sec-ch-ua': '"Google Chrome";v="141", "Not?A_Brand";v="8", "Chromium";v="141"',
    'sec-ch-ua-mobile': '?0',
    'sec-ch-ua-platform': '"Windows"',
    # 'Cookie': 'Hm_lvt_8ab7263c9280868f0c3ef17366bf585a=1761567514,1761616780; HMACCOUNT=CC5AE7EC56D6DB25; Hm_lpvt_8ab7263c9280868f0c3ef17366bf585a=1761618651',
}


BATCH_SIZE = 100  # Saved every 100 records
CSV_FILE_PATH = "real_time_data.csv"  # Final CSV file path


def get_single_html(url):
    """发送一次请求，获取页面HTML文本"""
    try:
        time.sleep(4)
        response = requests.get(url.strip(), cookies=cookies, headers=headers)
        return response.text.encode('latin-1').decode('utf-8', errors='ignore')
    except Exception as e:
        print(f"【首次请求失败】URL：{url}，错误：{e}")
        return None


def extract_next_url_from_html(html_tree, base_url):
    """提取下一页URL，无下一页返回None"""
    try:
        next_href = html_tree.xpath(
            '/html/body/table[1]//tr[3]/td/table//tr/td[2]/table//tr[2]/td/table//tr[4]/td/table//tr/td[1]/table//tr/td[2]/a/@href'
        )
        if not next_href or next_href[0].strip() == "javascript:alert('已经是最后一篇')":
            return None
        base_prefix = base_url.split("content")[0]
        return base_prefix + next_href[0].strip()
    except Exception as e:
        print(f"【提取下一页失败】错误：{e}")
        return None


def extract_page_data_from_html(html_tree, url):
    """提取当前页数据，无效页返回None"""
    try:
        # Extract titles and filter ads
        title = "".join(html_tree.xpath('//*[@id="article-title"]/founder-title/text()')).strip()
        if title == "广告":
            print(f"【跳过广告页】URL：{url}")
            return None

        # Extract the main text and author
        content = ""
        founder_node = html_tree.xpath('//*[@id="ozoom"]/founder-content')
        name_1 = ''.join(html_tree.xpath("/html/body/table[1]//tr[3]/td/table//tr/td[2]/table//tr[2]/td/table//tr[2]/td/div/table//tr[1]/td/table//tr[4]/td/founder-author/text()")).strip()
        names = name_1 if name_1 else None

        if names is not None:
            if founder_node:
                p_texts = [p.strip() for p in founder_node[0].xpath('.//text()') if p.strip()]
                content = "。".join(p_texts)
        else:
            names = "".join(founder_node[0].xpath('./text()')).strip() if founder_node else ""
            if len(names) > 15:
                names = ''
                # Try to extract the author from the last 2 p tags
                name_2 = "".join(founder_node[0].xpath('./p[last()]/text()')).strip() if founder_node else ""
                if name_2 and len(name_2) < 10:
                    names = name_2
                else:
                    name_3 = "".join(founder_node[0].xpath('./p[last()-1]/text()')).strip() if founder_node else ""
                    names = name_3 if (name_3 and len(name_3) < 10) else ""
                # Extract the main text
                if founder_node:
                    p_texts = [p.strip() for p in founder_node[0].xpath('.//text()') if p.strip()]
                    content = "。".join(p_texts)
            else:
                if founder_node:
                    p_texts = [p.strip() for p in founder_node[0].xpath('.//P/text() | .//p/text()') if p.strip()]
                    content = "。".join(p_texts)

        # Handle cases without authors
        names = names if names else " "
        # Extract time and version number information from the URL
        year = url.split('/content')[0].split('html/')[1].split('/')[0]
        day = url.split('/content')[0].split('html/')[1].split('/')[1]
        page_number = url.split('/content')[1].split('_')[1]

        return {
            "doc_id": f"{year}-{day}_{page_number}_{title}",
            "date_raw": f"{year}-{day}",
            "year": year.split('-')[0],
            "month": year.split('-')[1],
            "page_number": page_number,
            "title": title,
            "body_text": content,
            "author": names,
            "tags_manual": "",
            "url": url,
        }
    except Exception as e:
        print(f"【提取页面数据失败】URL：{url}，错误：{e}")
        return None


def process_url_chain(initial_url, batch_cache, save_count, has_written_header):
    """处理单个URL链，实时累计数据到缓存，满100条立即保存"""
    current_url = initial_url
    while current_url:
        current_html = get_single_html(current_url)
        if not current_html:
            print(f"【终止URL链】URL：{current_url}（未获取到HTML）")
            break

        html_tree = etree.HTML(current_html)
        page_data = extract_page_data_from_html(html_tree, current_url)
        if page_data:
            batch_cache.append(page_data)
            print(f"【累计数据】当前缓存{len(batch_cache)}条，URL：{current_url}")

            # Save immediately when the cache is full (100 entries)
            if len(batch_cache) >= BATCH_SIZE:
                save_count += 1
                has_written_header = save_batch_to_csv(batch_cache, save_count, has_written_header)
                batch_cache.clear()  # Clear the cache after saving to free up memory

        # Get the URL of the next page and continue the loop
        current_url = extract_next_url_from_html(html_tree, current_url)
    return batch_cache, save_count, has_written_header


def save_batch_to_csv(batch_data, batch_num, has_written_header):
    """保存单批数据到CSV，控制表头只写一次"""
    csv_headers = ["doc_id", "date_raw", "year", "month", "page_number", "title", "body_text", "author", "tags_manual", "url"]
    with open(CSV_FILE_PATH, 'a', newline='', encoding='utf-8-sig') as f:
        writer = csv.DictWriter(f, fieldnames=csv_headers)
        # The first save writes the header data; subsequent saves only write the data
        if not has_written_header:
            writer.writeheader()
            has_written_header = True
        writer.writerows(batch_data)
    print(f"【批量保存完成】第{batch_num}批，共{len(batch_data)}条数据已写入{CSV_FILE_PATH}\n")
    return has_written_header


if __name__ == '__main__':
    # Initialization: Temporary cache (stores data with fewer than 100 records), batch count, header write flag
    batch_cache = []
    save_count = 0
    has_written_header = False
    input_file_path = "result.txt"  # 初始URL列表文件

    try:
        # Read all initial URLs
        with open(input_file_path, 'r', encoding='utf-8') as f:
            initial_urls = [line.strip() for line in f.readlines() if line.strip()]
        if not initial_urls:
            print(f"【错误】文件'{input_file_path}'中无有效URL")
            exit()

        # Process each initial URL chain, accumulate and save data in real time
        for idx, initial_url in enumerate(initial_urls, 1):
            print(f"\n===== 开始处理第{idx}个初始URL链：{initial_url} =====")
            batch_cache, save_count, has_written_header = process_url_chain(
                initial_url, batch_cache, save_count, has_written_header
            )
            print(f"第{idx}个URL链处理完毕，当前缓存剩余{len(batch_cache)}条数据\n")

        # After processing all URL chains, save the remaining data (less than 100 records)
        if batch_cache:
            save_count += 1
            has_written_header = save_batch_to_csv(batch_cache, save_count, has_written_header)
            batch_cache.clear()

        print(f"===== 所有任务完成！共保存{save_count}批数据，文件路径：{CSV_FILE_PATH} =====")

    except FileNotFoundError:
        print(f"【错误】未找到初始URL文件：{input_file_path}")
    except Exception as e:
        # In case of an error, save the remaining data in the cache to avoid data loss
        if batch_cache:
            save_count += 1
            save_batch_to_csv(batch_cache, save_count, has_written_header)

        print(f"【程序异常终止】错误：{e}，已保存缓存中剩余数据")
