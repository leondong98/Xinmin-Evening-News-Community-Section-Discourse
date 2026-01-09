# Xinmin Evening News (Community Section) Discourse Dataset 新民晚报社区版（业主周刊）文本数据集
Python crawler and R based text analysis scripts for *Governance Through Ambiguity: Local Elites and Institutional Adaptation in Urban Shanghai*. Includes 15,498 community governance reports from Xinmin Evening News (2011–2019), cleaned and analyzed for role–action and strategy patterns in grassroots governance.

## 1. Overview
This project builds a structured corpus of Shanghai’s grassroots governance discourse, combining both computational text analysis and qualitative theories.
It forms the quantitative foundation of the paper’s textual analysis section.

## 2. Main Objectives
Extract and structure all community-related reports from Xinmin Evening News (Community Section)
- Identify grassroots elite roles (e.g., neighborhood cadres, property managings, party branches, grids, volunteers)
- Detect and model governance action strategies (coordination, evasion, and proactive strategies)
- Visualize temporal dynamics and role–strategy interactions (2011–2019)


## 3. Repository Structure
├── Python crawler and dataset/
│   ├── get_base_url.py       # Crawl section base URLs
│   ├── get_context.py        # Extract full article content
│   ├── get_navi_url.py       # Iterate and navigate paginated archives
│   ├── result.txt            # Sample crawl results
│   └── real_time_data.csv    # Final cleaned dataset (via Git LFS)
│
├── role_strategy_analysis.R  # R scripts for text cleaning, parsing, and trend modeling
├── result_visualization.R    # Temporal and role–strategy visualization (GAM/LOESS)
└── README.mdb
