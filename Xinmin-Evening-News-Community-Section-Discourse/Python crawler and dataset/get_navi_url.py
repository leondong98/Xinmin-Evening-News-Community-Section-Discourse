import re
import time
from math import ceil

import requests

cookies = {
    # 'Hm_lvt_8ab7263c9280868f0c3ef17366bf585a': '1761567514,1761616780',
    'HMACCOUNT': 'CC5AE7EC56D6DB25',
    'Hm_lpvt_8ab7263c9280868f0c3ef17366bf585a': str(ceil(time.time())),
}

headers = {
    'Accept': 'text/javascript, text/html, application/xml, text/xml, */*',
    'Accept-Language': 'zh-CN,zh;q=0.9',
    'Cache-Control': 'no-cache',
    'Connection': 'keep-alive',
    'Pragma': 'no-cache',
    'Referer': 'https://xmwb.xinmin.cn/xmwbzone/html/2011-11/30/node_1.htm',
    'Sec-Fetch-Dest': 'empty',
    'Sec-Fetch-Mode': 'cors',
    'Sec-Fetch-Site': 'same-origin',
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/141.0.0.0 Safari/537.36',
    'X-Prototype-Version': '1.5.0_rc0',
    'X-Requested-With': 'XMLHttpRequest',
    'sec-ch-ua': '"Google Chrome";v="141", "Not?A_Brand";v="8", "Chromium";v="141"',
    'sec-ch-ua-mobile': '?0',
    'sec-ch-ua-platform': '"Windows"',
    # 'Cookie': 'Hm_lvt_8ab7263c9280868f0c3ef17366bf585a=1761567514,1761616780; HMACCOUNT=CC5AE7EC56D6DB25; Hm_lpvt_8ab7263c9280868f0c3ef17366bf585a=1761618651',
}
# Initialize start date and month
current_year = 2011
current_month = 11
year_month_strings = []  # String format "year-month"

# Generate all years and months in a loop
while True:
    # Add current year and month to list
    year_month_strings.append(f"{current_year}-{current_month:02d}")  # Monthly zeros should be kept to 2 digits

    # Determine if the endpoint has been reached (September 2019)
    if current_year == 2019 and current_month == 9:
        break

    # Monthly increments, handling year-end situations
    current_month += 1
    if current_month > 12:
        current_month = 1
        current_year += 1


def get_request(data):
    response = requests.get(f'https://xmwb.xinmin.cn/xmwbzone/html/{data}/navi.xml', cookies=cookies, headers=headers)
    return response.text


with open('1.txt', 'w', encoding='utf-8') as f:
    for i in year_month_strings:
        resp_data = get_request(i)
        fill_url = re.findall(r'<url>(.*?)</url>', resp_data)
        for j in fill_url:
            url = 'https://xmwb.xinmin.cn/xmwbzone/html/'+i+j.split('..')[1]
            f.write(url+'\n')
        time.sleep(1)


