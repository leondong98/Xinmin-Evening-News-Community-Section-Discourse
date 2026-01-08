
from lxml import etree
import requests
import re
import time
from math import ceil

cookies = {
    # 'Hm_lvt_8ab7263c9280868f0c3ef17366bf585a': '1761567514,1761616780',
    'HMACCOUNT': 'CC5AE7EC56D6DB25',
    'Hm_lpvt_8ab7263c9280868f0c3ef17366bf585a': str(ceil(time.time())),
}

headers = {
    'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.7',
    'Accept-Language': 'zh-CN,zh;q=0.9',
    'Cache-Control': 'no-cache',
    'Connection': 'keep-alive',
    'Pragma': 'no-cache',
    'Sec-Fetch-Dest': 'document',
    'Sec-Fetch-Mode': 'navigate',
    'Sec-Fetch-Site': 'none',
    'Sec-Fetch-User': '?1',
    'Upgrade-Insecure-Requests': '1',
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/141.0.0.0 Safari/537.36',
    'sec-ch-ua': '"Google Chrome";v="141", "Not?A_Brand";v="8", "Chromium";v="141"',
    'sec-ch-ua-mobile': '?0',
    'sec-ch-ua-platform': '"Windows"',
    # 'Cookie': 'Hm_lvt_8ab7263c9280868f0c3ef17366bf585a=1761567514,1761616780; HMACCOUNT=CC5AE7EC56D6DB25; Hm_lpvt_8ab7263c9280868f0c3ef17366bf585a=1761618651',
}


def get_request(data):
    response = requests.get(data, cookies=cookies,
                            headers=headers)
    datas = response.text.encode('latin-1')
    return datas.decode('utf-8')


with open('1.txt', 'r', encoding='utf-8') as f:
    for line in f.readlines():
        url = line.strip()  # Remove trailing newline characters and spaces
        if not url:
            continue  # Skip blank lines

        # Get webpage HTML content
        html_text = get_request(url)
        if not html_text:
            continue  # Skip if content is empty

        # Parse HTML into objects that can be queried using XPath
        try:
            html = etree.HTML(html_text)
        except Exception as e:
            print(f"解析HTML失败：{e}")
            continue

        # Use XPath to locate the target a tag (//*[@id="bmdhTable"]/tbody/tr/td[1]/a)
        a_elements = html.xpath('//*[@id="bmdhTable"]/tbody/tr/td[1]/a')

        # Iterate through all `<a>` tags and determine if the text contains "Homeowners' Weekly (业主周刊)"
        for a in a_elements:
            # Get the text content of the <a> tag (handling possible whitespace characters)
            a_text = a.text.strip() if a.text else ""
            # Determine whether it includes "Homeowners' Weekly (业主周刊)".
            if "业主周刊" in a_text:
                # Extract href attribute
                href = a.get('href')
                url_base = url.split('node_1')[0]+'content_'+re.findall(r'\d+', href)[0]+'_1.htm'
                # print(url_base)
                # If you need to save, you can add the logic for writing to a file here.
                with open('result.txt', 'a', encoding='utf-8') as res_f:
                    res_f.write(f"{url_base}\n")
        time.sleep(1)


