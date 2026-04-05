# 06_multi_agent_lab.R
# 3-agent flow: Agent1 data collection (output=captured data) -> Agent2 data analysis -> Agent3 daily report + 30-day review
# API key: API_KEY in 06_agents/.env (Alpha Vantage)

# Set working directory to script location
args = commandArgs(trailingOnly = FALSE)
match = grep("^--file=", args)
if (length(match) > 0) {
  script_path = sub("^--file=", "", args[match])
  if (nzchar(script_path) && file.exists(script_path)) {
    setwd(dirname(normalizePath(script_path)))
  }
}

if (file.exists(".env")) readRenviron(".env")
API_KEY = Sys.getenv("API_KEY")
if (!nzchar(API_KEY)) API_KEY = "demo"

if (!requireNamespace("ollamar", quietly = TRUE)) {
  install.packages("ollamar", repos = "https://cloud.r-project.org")
}
library(dplyr)
library(httr2)
library(jsonlite)
library(ollamar)
library(purrr)
source("functions.R")

# Smallest model for speed (135M params). Pull with: ollama pull smollm2:135m
# Alternative: tinyllama (1.1B, often faster inference): MODEL = "tinyllama"
MODEL = "smollm2:135m"
SYMBOL = "IBM"

# =============================================================================
# Data fetch (done in code; result is input to Agent 1)
# =============================================================================
url_av = "https://www.alphavantage.co/query"
req = request(url_av) |>
  req_url_query(
    `function` = "TIME_SERIES_DAILY",
    symbol = SYMBOL,
    apikey = API_KEY
  ) |>
  req_method("GET")
resp = req_perform(req)
if (resp_status(resp) != 200) stop("Alpha Vantage request failed. Check API key and .env.")
data = resp_body_json(resp)
ts = data[["Time Series (Daily)"]]
if (is.null(ts)) stop("No time series in response.")

dates = names(ts)
out = lapply(seq_along(dates), function(i) {
  d = ts[[i]]
  data.frame(
    date = dates[i],
    open = as.numeric(d[["1. open"]]),
    high = as.numeric(d[["2. high"]]),
    low = as.numeric(d[["3. low"]]),
    close = as.numeric(d[["4. close"]]),
    volume = as.numeric(d[["5. volume"]]),
    stringsAsFactors = FALSE
  )
})
df_stock = do.call(rbind, out)
df_stock = df_stock[order(df_stock$date, decreasing = TRUE), ]
df_stock = head(df_stock, 30)
df_stock = df_stock[order(df_stock$date), ]

# Agent 1: Captured data = full daily table (many rows), built in code (no LLM)
# Each row = one trading day: date, open, high, low, close, volume
df_stock$volume = round(df_stock$volume, 0)  # avoid scientific notation in table
out_agent1 = df_as_text(df_stock)

# =============================================================================
# Agent 2: Data analysis — output = overview + trends/findings + conclusion only
# =============================================================================
ROLE_AGENT2 = "You are a data analyst. The user provides a table of captured stock data. Your output is analysis only — no report, no recommendations. Use exactly these three sections:
## Data Overview
[1-2 sentences: what the table covers and key numbers]
## Trends and Findings
- [bullet 1]
- [bullet 2]
- [bullet 3]
## Conclusion
[1-2 sentences: analytical conclusion only]
Use only numbers from the table. Do not write a daily report or 30-day review; that is done by the next agent."

out_agent2 = agent_run(role = ROLE_AGENT2, task = out_agent1, model = MODEL, output = "text")

# =============================================================================
# Agent 3: Report writing — two distinct reports (daily + 30-day review)
# =============================================================================
ROLE_AGENT3 = "You are a report writer. You receive an analysis (Data Overview, Trends, Conclusion). Your job is to write TWO separate reports — do not repeat or copy the analysis text.
## Daily Report
[Short report for the latest trading day: key price, volume, one-paragraph snapshot. Reader-facing.]
## 30-Day Review Report
[Separate report: past 30 days performance, trend summary, and a brief recommendation. Do not duplicate the Daily Report.]
Keep Daily Report and 30-Day Review Report clearly different in content and purpose."

out_agent3 = agent_run(role = ROLE_AGENT3, task = out_agent2, model = MODEL, output = "text")

# =============================================================================
# Output
# =============================================================================
cat("========== Agent 1 output (captured data) ==========\n")
cat(out_agent1, "\n\n")
cat("========== Agent 2 output (data analysis) ==========\n")
cat(out_agent2, "\n\n")
cat("========== Agent 3 output (daily report + 30-day review) ==========\n")
cat(out_agent3, "\n")
cat("========== End of workflow ==========\n")




