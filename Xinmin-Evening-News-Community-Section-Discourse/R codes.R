setwd("your_working_directory")


library(showtext)
library(sysfonts)
library(quanteda)
library(tidytext)
library(usethis)
library(devtools)
library(jiebaRD)
library(jiebaR)
library(stringr)
library(readr)
library(dplyr)
library(tidyverse)
library(stringr)

#### Text Cleaning and Filtering #############################################################

# 1. Keep only topic-related keywords (initial filtering)
keep_words <- c("物业","业主","小区","服务","管理","政府","社区","居委","业委","委员会","居委会")
keep_regex <- paste(keep_words, collapse = "|")

# 2. Define blacklist keywords for advertisements and commercial content
ad_words <- c(
  # Promotions / transactions
  "购买","买","售价","报价","价格","仅需","低至","促销","优惠","折扣","赠送",
  "福利","返利","返现","抽奖","秒杀","团购","拼团","下单","订购","现货","库存",
  # E-commerce platforms / stores
  "天猫","京东","淘宝","拼多多","旗舰店","专卖店","店铺","商城",
  # Clickbait / call-to-action
  "点击","详情","了解更多","立即","马上","阅读原文","原文链接",
  # Contact info / business collaboration
  "咨询","客服","热线","电话","致电","拨打","添加微信","VX","QQ","商务合作","合作","推广","广告",
  # Apps / downloads
  "下载","App","APP","客户端","安装","注册","登录",
  # Reposts / copyright notices (common in press releases or footnotes)
  "免责声明","转载","版权","来源","记者","编辑"
)
ad_regex <- paste(ad_words, collapse = "|")

# 3. Whitelist (governance / policy-related context)
whitelist_words <- c(
  "通知","通报","公告","公示","会议","纪要","征求意见","意见稿","条例","规定","办法","实施细则",
  "方案","整改","督查","问责","处罚","执法","物业服务","物业管理委员会","社区居委会","街道办"
)
whitelist_regex <- paste(whitelist_words, collapse = "|")

# 4. Structural filtering rules
url_regex    <- "https?://|www\\."
phone_regex  <- "(?:\\D|^)(1[3-9]\\d{9})(?:\\D|$)|\\d{3,4}-\\d{7,8}"  # phone number
price_regex  <- "[¥￥]\\s?\\d+|\\d+\\s?元"

df <- data %>%
  # Keep only texts containing topic-related keywords
  filter(str_detect(body_text, keep_regex)) %>%
  # Add feature flags
  mutate(
    has_ad   = str_detect(body_text, ad_regex),
    has_url  = str_detect(body_text, url_regex),
    has_tel  = str_detect(body_text, phone_regex),
    has_price= str_detect(body_text, price_regex),
    n_digits = str_count(body_text, "\\d"),
    has_white= str_detect(body_text, whitelist_regex)
  ) %>%
  # Exclude texts containing ads / URLs / phone numbers / prices / excessive digits,
  # unless they also match the whitelist (governance context)
  filter(!( (has_ad | has_url | has_tel | has_price | n_digits >= 10) & !has_white )) %>%
  # Remove very short texts (often ads or footers)
  filter(str_length(body_text) >= 20) %>%
  # Deduplicate entries (by body text or title + body)
  distinct(body_text, .keep_all = TRUE)

write_csv(df, "real_time_data_screening.csv")

#################################################################################


#################################################################################
# Screened Data
df <- readr::read_csv("real_time_data_screening.csv")

# Elite Dictionary
elite_lex <- c(
  "居委会委员","居委成员","居委班子","居委骨干","居委会主任","居委副书记",
  "社区党支部","社区党委","党总支书记","党群干部","党建指导员",
  "居民小组长","邻里中心工作人员","自治骨干","自治志愿者","自治小组",
  "业委会成员","业委会主任","筹备组成员","监事成员",
  "物业经理","楼栋物业联络员","楼栋志愿者",
  "网格长","网格信息员","楼片负责人","门栋长",
  "社区党员","党员骨干","先锋党员","预备党员",
  "志愿服务队","志愿队队长","文明志愿者","巡逻志愿者",
  "驻点社工","社工团队","社工骨干",
  "协调员","调解员","宣传员","巡逻队员","联防队员","业委会","筹备组","居委干部"
)

# Action Strategy Words
verbs_focus <- c(
  "带头","组织","协调","调解","服务","监督","宣传","动员","参与","推进","落实",
  "发现","排查","巡查","走访","入户","摸排","倾听","受理","接访","反馈","回应",
  "协商","统筹","联动","牵头","联系","召集","调处","沟通","磋商",
  "整改","整治","执勤","劝导","巡逻","处置","制止","约谈","督促","检查",
  "共建","共治","共商","创新","试点","探索","完善","规范","制定规则","执行制度",
  "关怀","探访","援助","帮扶","配合","志愿服务","互助","代办","救助"
)


#################################################################################

## Sentence-level Extraction
# Split texts into sentences (rough segmentation using period/question/exclamation marks)
sentences <- df %>%
  mutate(
    doc_row = row_number(),
    year = as.numeric(year),
    month = as.numeric(month)
  ) %>%
  separate_rows(body_text, sep = "(?<=[。！？])") %>%
  filter(nchar(body_text) > 0) %>%
  rename(sentence = body_text)

# Keep only sentences containing elite-related role terms
elite_sent <- sentences %>%
  filter(str_detect(sentence, str_c(elite_lex, collapse="|"))) %>%
  mutate(
    ym = sprintf("%04d-%02d", year, month),
    date = as.Date(paste0(ym, "-01"))
  )



## Lightweight features: extract adjectives / verbs of interest

elite_sent <- elite_sent %>%
  mutate(
    has_pos = str_detect(sentence, str_c(pos_lex, collapse="|")),
    has_neg = str_detect(sentence, str_c(neg_lex, collapse="|")),
    verbs   = str_extract_all(sentence, str_c(verbs_focus, collapse="|"))
  )




## Dependency Parsing

# Install Chinese model if not already available
#install.packages("udpipe")
library(udpipe)
library(dplyr)
library(stringr)
#udpipe::udpipe_download_model(language = "chinese-gsd")

# = Load the Chinese dependency model
m <- udpipe_load_model(udpipe_download_model("chinese-gsd")$file_model)

role_regex <- str_c(elite_lex, collapse = "|")

# Assign each sentence a unique ID for udpipe’s doc_id
elite_sent <- elite_sent %>%
  mutate(ud_id = paste0("s", row_number()))

# Run udpipe with doc_id = ud_id (to enable later joining)
anno <- udpipe_annotate(m,
                        x = elite_sent$sentence,
                        doc_id = elite_sent$ud_id)
par <- as.data.frame(anno)

# Within each sentence (doc_id), extract role terms, modifiers, and verbs; then summarize by doc_id
desc_from_dep <- par %>%
  group_by(doc_id) %>%
  summarise(
    # Role terms (merged after deduplication)
    roles = paste(unique(token[str_detect(token, role_regex)]), collapse = ";"),
    # Adjectives modifying role terms (amod dependency relation pointing to role terms)
    adj_to_role = paste(
      unique(token[dep_rel == "amod" &
                     head_token_id %in% token_id[str_detect(token, role_regex)]]),
      collapse = ";"
    ),
    # Verbs where roles act as subjects + verbs governed by role terms (union of both sets)
    verb_by_role = paste(
      unique(c(
        # Role term as subject, its head is a verb
        lemma[dep_rel == "nsubj" &
                head_token_id %in% token_id[str_detect(token, role_regex)] &
                upos == "VERB"],
        # Role term as noun, directly governing verb child nodes
        token[upos == "VERB" &
                head_token_id %in% token_id[str_detect(token, role_regex)]]
      )),
      collapse = ";"
    ),
    .groups = "drop"
  )

# Align by ud_id and left_join back (avoid bind_cols to ensure key-based merge)
elite_sent_dep <- elite_sent %>%
  left_join(desc_from_dep, by = c("ud_id" = "doc_id")) %>%
  mutate(
    roles        = coalesce(roles, ""),
    adj_to_role  = coalesce(adj_to_role, ""),
    verb_by_role = coalesce(verb_by_role, "")
  )


#################################################################################



#################################################################################
# 3 Types of Action Logic 

library(dplyr); library(stringr); library(tidyr); library(purrr)


# Coordination Strategy
coordination_lex <- c(
  "协调","协同","统筹","联动","对接","协商","沟通","调解",
  "衔接","解释","释疑","联席","联合",
  "共同推进","整合资源",
  "资源统筹","共同参与","群策群力","多方协商","联手","多部门配合"
)

# Evasion Strategy
evasion_lex <- c(
  "形式上","形式化","走形式","走过场","象征性","象征执行",
  "按要求","按规定","按程序","达到指标","完成任务","达标",
  "上报","备案","例行检查","通过验收","标准化流程",
  "委托","外包","移交","推诿","被动落实","表面合规"
)

# Proactive Strategy
proactive_lex <- c(
  "自发","主动","带头","倡导","倡议","发起","推动",
  "共建","联建","自治","议事","居民议事","提案",
  "试点","创新","探索","机制创新","共治","发动居民",
  "自下而上","培育骨干","培育社团","社区营造","议题设置"
)


## Sentence-level tagging (which strategy applies to each sentence)

library(stringr)
library(dplyr)
library(tidyr)

elite_strat <- elite_sent_scores %>%
  mutate(
    coord_hits = str_count(sentence, str_c(coordination_lex, collapse="|")),
    evas_hits  = str_count(sentence, str_c(evasion_lex,     collapse="|")),
    proa_hits  = str_count(sentence, str_c(proactive_lex,   collapse="|")),
    coord_flag = as.integer(coord_hits > 0),
    evas_flag  = as.integer(evas_hits  > 0),
    proa_flag  = as.integer(proa_hits  > 0)
  )


## Broad to Long: Constructing a Strength Indicator for the "Monthly × Strategy"

## Two Measurements
# M1:Sentence Count: Number of sentences that use the strategy at least once in the current month
# M2: Word Frequency Count: Total number of hits in the current month

# M1
strat_month_M1 <- elite_strat %>%
  transmute(date, year, month,
            coordination = coord_flag, evasion = evas_flag, proactive = proa_flag) %>%
  pivot_longer(cols = c(coordination, evasion, proactive),
               names_to = "strategy", values_to = "flag") %>%
  group_by(date, strategy) %>%
  summarise(n = sum(flag), .groups = "drop")    # Monthly "Number of Sentences Hit"

# M2
strat_month_M2 <- elite_strat %>%
  transmute(date, year, month,
            coordination = coord_hits, evasion = evas_hits, proactive = proa_hits) %>%
  pivot_longer(cols = c(coordination, evasion, proactive),
               names_to = "strategy", values_to = "hits") %>%
  group_by(date, strategy) %>%
  summarise(n = sum(hits), .groups = "drop")    # Monthly "Total Number of Hits"

# Select caliber: Use M1 first. If M2 is needed, change `strat_month <- strat_month_M1` below to M2.
strat_month <- strat_month_M1

# Complete the month and calculate the total amount and percentage for the current month.
all_months <- tibble(date = seq(min(strat_month$date), max(strat_month$date), by = "month"))
strat_month <- all_months %>%
  expand_grid(strategy = c("coordination", "evasion", "proactive")) %>%
  left_join(strat_month, by = c("date","strategy")) %>%
  mutate(n = tidyr::replace_na(n, 0L)) %>%
  group_by(date) %>%
  mutate(total = sum(n), prop = ifelse(total > 0, n/total, 0)) %>%
  ungroup()


## Visualization

library(mgcv)
library(ggplot2)

pal_strat <- c(coordination = "#6b92c3",  
               evasion      = "#a90b2f",  
               proactive    = "#f3683c")  

# Use small epsilon values to avoid logit values of 0 or 1
eps <- 1e-4
dat_prop <- strat_month %>%
  mutate(p = pmin(pmax(prop, eps), 1 - eps),
         base_date = min(date),
         t_years   = as.numeric(difftime(date, base_date, units="days"))/365.25)

# Binomial-GAM (using total as the weight)
fit_one_prop <- function(df, k = 30){
  gam(p ~ s(t_years, k = k, bs = "cr"),
      data = df, weights = df$total,
      family = quasibinomial(link = "logit"),
      method = "REML")
}

mods_prop <- dat_prop %>%
  group_by(strategy) %>%
  group_map(~ list(strategy = .y$strategy, model = fit_one_prop(.x), data = .x))

pred_prop <- lapply(mods_prop, function(m){
  d  <- m$data %>% arrange(t_years)
  pr <- predict(m$model, newdata = d, se.fit = TRUE, type = "link")
  tibble(
    strategy = m$strategy,
    date     = d$date,
    fit      = plogis(pr$fit),
    lwr      = plogis(pr$fit - 1.96*pr$se.fit),
    upr      = plogis(pr$fit + 1.96*pr$se.fit) 
  )
}) %>% bind_rows()

ggplot() +
  geom_ribbon(data = pred_prop,
              aes(date, ymin = lwr, ymax = upr, group = strategy),
              inherit.aes = FALSE, fill = "grey20", alpha = 0.06) +
  geom_line(data = pred_prop,
            aes(date, fit, color = strategy), linewidth = 1.15) +
  geom_point(data = strat_month,
             aes(date, prop, color = strategy),
             size = 0.9, alpha = 0.22) +
  scale_color_manual(values = pal_strat, name = "Strategy",
                     labels = c(coordination="Coordination",
                                evasion="Evasion/Formality",
                                proactive="Proactive/Bottom-up")) +
  scale_y_continuous(labels = scales::percent_format(accuracy = 1)) +
  theme_minimal(base_size = 14) +
  theme(legend.position="top",
        panel.grid.minor = element_blank(),
        plot.title = element_text(face="bold")) +
  labs(x = "Month", y = "Share of mentions",
       title = "Action Strategies in Official Media (Share by Month)")



## Plot the "count" trend (if absolute values are needed)
# Counting method: quasi-Poisson (same dat as above, but using n)
dat_cnt <- strat_month %>%
  mutate(base_date = min(date),
         t_years   = as.numeric(difftime(date, base_date, units="days"))/365.25)

fit_one_cnt <- function(df, k = 30){
  gam(n ~ s(t_years, k = k, bs = "cr"),
      data = df, family = quasipoisson(link = "log"),
      method = "REML")
}

mods_cnt <- dat_cnt %>%
  group_by(strategy) %>%
  group_map(~ list(strategy = .y$strategy, model = fit_one_cnt(.x), data = .x))

pred_cnt <- lapply(mods_cnt, function(m){
  d  <- m$data %>% arrange(t_years)
  pr <- predict(m$model, newdata = d, se.fit = TRUE, type = "link")
  tibble(
    strategy = m$strategy,
    date     = d$date,
    fit      = exp(pr$fit),
    lwr      = exp(pr$fit - 1.96*pr$se.fit)
  )
}) %>% bind_rows()

ggplot() +
  geom_ribbon(data = pred_cnt,
              aes(date, ymin = lwr, ymax = fit, group = strategy),
              inherit.aes = FALSE, fill = "grey20", alpha = 0.06) +
  geom_line(data = pred_cnt,
            aes(date, fit, color = strategy), linewidth = 1.15) +
  geom_point(data = strat_month,
             aes(date, n, color = strategy), size = 0.9, alpha = 0.22) +
  scale_y_log10() +
  scale_color_manual(values = pal_strat, name = "Strategy",
                     labels = c(coordination="Coordination",
                                evasion="Evasion/Formality",
                                proactive="Proactive/Bottom-up")) +
  theme_minimal(base_size = 14) +
  theme(legend.position="top",
        panel.grid.minor = element_blank(),
        plot.title = element_text(face="bold")) +
  labs(x = "Month", y = "Mention Frequency (log scale)",
       title = "Action Strategies in Official Media (Counts by Month)")


#################################################################################
# Interaction trends of strategies based on role type

#################################################################################

library(dplyr)
library(stringr)
library(tidyr)

library(dplyr)
library(stringr)
library(tidyr)

# Regex for each elite role category
rx_comm_party      <- str_c(pat_comm_party,      collapse="|")
rx_owners_property <- str_c(pat_owners_property, collapse="|")
rx_block_grid      <- str_c(pat_block_grid,      collapse="|")
rx_party_vol_sw    <- str_c(pat_party_vol_sw,    collapse="|")
rx_govern_actors   <- str_c(pat_govern_actors,   collapse="|")

# Sentence → Multi-role labels (TRUE = matched)
role_long <- elite_sent_scores %>%
  mutate(
    r_comm_party      = str_detect(sentence, rx_comm_party)      | str_detect(roles, rx_comm_party),
    r_owners_property = str_detect(sentence, rx_owners_property) | str_detect(roles, rx_owners_property),
    r_block_grid      = str_detect(sentence, rx_block_grid)      | str_detect(roles, rx_block_grid),
    r_party_vol_sw    = str_detect(sentence, rx_party_vol_sw)    | str_detect(roles, rx_party_vol_sw),
    r_govern_actors   = str_detect(sentence, rx_govern_actors)   | str_detect(roles, rx_govern_actors)
  ) %>%
  transmute(
    ud_id, date, year, month,
    `Neignborhood/Party Org.`                 = r_comm_party,
    `Homeowners/Property Org.`                = r_owners_property,
    `Block/Grid System`                       = r_block_grid,
    `Party Members/Volunteers/Social Workers` = r_party_vol_sw,
    `Volunteers/Mediators`                    = r_govern_actors
  ) %>%
  pivot_longer(-c(ud_id,date,year,month),
               names_to = "role_type", values_to = "flag") %>%
  filter(flag) %>%
  select(-flag)

## Action strategy detection
coord_rx     <- str_c(coordination_lex, collapse="|")
evasion_rx   <- str_c(evasion_lex,     collapse="|")
proactive_rx <- str_c(proactive_lex,   collapse="|")

# Flag whether a sentence hits a strategy term + count the number of hits → long format
strat_flags <- elite_sent_scores %>%
  transmute(
    ud_id, date, year, month,
    coordination = as.integer(str_detect(sentence, coord_rx)),
    evasion      = as.integer(str_detect(sentence, evasion_rx)),
    proactive    = as.integer(str_detect(sentence, proactive_rx))
  ) %>%
  pivot_longer(c(coordination, evasion, proactive),
               names_to = "strategy", values_to = "flag")

strat_hits <- elite_sent_scores %>%
  transmute(
    ud_id, date, year, month,
    coordination = str_count(sentence, coord_rx),
    evasion      = str_count(sentence, evasion_rx),
    proactive    = str_count(sentence, proactive_rx)
  ) %>%
  pivot_longer(c(coordination, evasion, proactive),
               names_to = "strategy", values_to = "hits")

strat_long <- strat_flags %>%
  left_join(strat_hits, by = c("ud_id","date","year","month","strategy")) %>%
  mutate(hits = tidyr::replace_na(hits, 0L)) %>%
  filter(strategy %in% c("coordination","evasion","proactive"))

## Combine into “Sentence × Role × Strategy” and aggregate to monthly level
pair_long <- role_long %>%
  inner_join(strat_long %>% filter(flag == 1),
             by = c("ud_id","date","year","month"))

# M1: Number of matched sentences
role_strat_M1 <- pair_long %>%
  group_by(date, role_type, strategy) %>%
  summarise(n_sent = n(), .groups = "drop")

# M2: Total count of matched keywords
role_strat_M2 <- role_long %>%
  inner_join(strat_long, by = c("ud_id","date","year","month")) %>%
  group_by(date, role_type, strategy) %>%
  summarise(n_hits = sum(hits), .groups = "drop")

# Choose method: use M2 here (for stability you can switch to M1 and replace n_hits with n_sent)
role_strat <- role_strat_M2 %>% rename(n = n_hits)

# Fill missing months
all_months <- tibble(date = seq(min(role_strat$date), max(role_strat$date), by = "month"))
role_strat <- all_months %>%
  tidyr::crossing(role_type = unique(role_long$role_type),
                  strategy  = c("coordination","evasion","proactive")) %>%
  left_join(role_strat, by = c("date","role_type","strategy")) %>%
  mutate(n = tidyr::replace_na(n, 0L))

# Calculate total number of sentences per “month × role” (as denominator)
role_total_by_month <- role_long %>%
  group_by(date, role_type) %>%
  summarise(role_total = n(), .groups = "drop")

role_strat <- role_strat %>%
  left_join(role_total_by_month, by = c("date","role_type")) %>%
  mutate(role_total = tidyr::replace_na(role_total, 0L),
         prop = ifelse(role_total > 0, n/role_total, 0))

## Robust smoothing: 4-month rolling window + Empirical Bayes + min sample threshold
library(zoo)
library(mgcv)
library(dplyr)
library(tidyr)
library(ggplot2)
library(purrr)

## Parameters
WIN     <- 4     # 4-month rolling window (more stable)
A_PRIOR <- 1     # Beta(a=b=1) conservative prior
MIN_PTS <- 4     # Minimum sample points; fallback to LOESS if < 4

## Compute rolling + Empirical Bayes smoothing
role_strat_smooth <- role_strat %>%
  arrange(role_type, strategy, date) %>%
  group_by(role_type, strategy) %>%
  mutate(
    n_roll          = rollsum(n, WIN, align="right", fill=NA),
    role_total_roll = rollsum(role_total, WIN, align="right", fill=NA),
    prop_eb         = (n_roll + A_PRIOR) / (role_total_roll + 2*A_PRIOR),
    # Winsorization to prevent extreme values
    prop_use        = pmin(pmax(prop_eb, 0.001), 0.999)
  ) %>% ungroup()

## Time axis adjustment + avoid 0/1 probabilities
eps <- 1e-4
dat <- role_strat_smooth %>%
  mutate(
    p = pmin(pmax(prop_use, eps), 1-eps),
    wt = role_total_roll
  ) %>%
  group_by(role_type) %>%
  mutate(
    base_date = min(date, na.rm=T),
    t_years   = as.numeric(difftime(date, base_date, units="days"))/365.25
  ) %>% ungroup()

## GAM model fitting (smooth curves)
fit_gam <- function(df){
  gam(p ~ s(t_years, k=15, bs="cr"),
      data=df, weights=df$wt,
      family=quasibinomial(link="logit"),
      method="REML", gamma=1.5)
}

## LOESS fallback (for small-sample groups)
fit_loess <- function(df){
  loess(p ~ t_years, data=df, weights=df$wt, span=.55)
}

## Model fitting: use LOESS if sample size < MIN_PTS
mods <- dat %>%
  group_by(role_type, strategy) %>%
  group_map(~{
    df <- .x %>% filter(!is.na(p))
    model <- if(nrow(df) < MIN_PTS) fit_loess(df) else fit_gam(df)
    list(role=.y$role_type, strat=.y$strategy, model=model, data=df)
  })

## Predictions
predict_one <- function(m){
  d <- m$data %>% arrange(t_years)
  if("gam" %in% class(m$model)){
    pr <- predict(m$model, newdata=d, se.fit=T, type="link")
    tibble(
      role_type = m$role, strategy=m$strat, date=d$date,
      fit = plogis(pr$fit),
      lwr = plogis(pr$fit - 1.96*pr$se.fit)
    )
  } else {
    pr <- predict(m$model, newdata=d)
    tibble(
      role_type = m$role, strategy=m$strat, date=d$date,
      fit = pmin(pmax(plogis(pr), 0),1), lwr = NA
    )
  }
}

pred <- map_df(mods, predict_one)

## Visualization
ggplot() +
  geom_ribbon(data = pred %>% filter(!is.na(lwr)),
              aes(date, ymin=lwr, ymax=fit, group=interaction(role_type,strategy)),
              inherit.aes=FALSE, fill="grey40", alpha=.08) +
  geom_line(data = pred, aes(date, fit, color=strategy), linewidth=1.1) +
  geom_point(data = dat, aes(date, p, color=strategy),
             size=1.0, alpha=.25) +
  scale_y_continuous(labels=scales::percent) +
  scale_color_manual(values=c(coordination="#5b83c1",
                              evasion="#9b0b28",
                              proactive="#e7632c"),
                     name="Strategy",
                     labels=c("Coordination","Evasion/Formality","Proactive/Bottom-up")) +
  facet_wrap(~ role_type, ncol=2, scales="free_y") +
  theme_minimal(base_size=14) +
  theme(legend.position="top",
        strip.text=element_text(face="bold"),
        plot.title=element_text(face="bold")) +
  labs(x="Month",
       y="Share within role (rolled+EB, %)",
       title="Interaction of Elite Role × Action Strategy Trends",
       subtitle="4-month rolling, empirical Bayes, GAM/LOESS hybrid smoothing")



