# 06_multi_agent_lab.py
# 3-agent flow: Agent1 data collection (output=captured data) -> Agent2 data analysis -> Agent3 daily report + 30-day review
# API key: API_KEY in 06_agents/.env (Alpha Vantage)

# 0. SETUP ###################################
import os
_script_dir = os.path.dirname(os.path.abspath(__file__))
os.chdir(_script_dir)

def _load_dotenv(path=".env"):
    if not os.path.isfile(path):
        return
    with open(path, "r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if line and not line.startswith("#") and "=" in line:
                k, v = line.split("=", 1)
                os.environ[k.strip()] = v.strip()

_load_dotenv(".env")
API_KEY = os.environ.get("API_KEY", "demo")

import requests
import pandas as pd
from functions import agent_run, df_as_text

# Smallest model for speed (135M params). Pull with: ollama pull smollm2:135m
# Alternative: tinyllama (1.1B, often faster inference): MODEL = "tinyllama"
MODEL = "smollm2:135m"
SYMBOL = "IBM"

# 1. Data fetch (done in code; result is input to Agent 1) ###################################
url_av = "https://www.alphavantage.co/query"
params = {"function": "TIME_SERIES_DAILY", "symbol": SYMBOL, "apikey": API_KEY}
resp = requests.get(url_av, params=params)
resp.raise_for_status()
data = resp.json()
ts = data.get("Time Series (Daily)")
if not ts:
    raise SystemExit("No time series in response. Check API key and symbol.")

rows = []
for date_str, d in ts.items():
    rows.append({
        "date": date_str,
        "open": float(d["1. open"]),
        "high": float(d["2. high"]),
        "low": float(d["3. low"]),
        "close": float(d["4. close"]),
        "volume": int(float(d["5. volume"])),
    })
df_stock = pd.DataFrame(rows)
df_stock = df_stock.sort_values("date", ascending=False).head(30)
df_stock = df_stock.sort_values("date").reset_index(drop=True)

# Agent 1: Captured data = full daily table (many rows), built in code (no LLM)
# Each row = one trading day: date, open, high, low, close, volume
df_stock["volume"] = df_stock["volume"].astype(int)
out_agent1 = df_as_text(df_stock)

# 3. Agent 2: Data analysis — output = overview + trends/findings + conclusion only ###################################
ROLE_AGENT2 = """You are a data analyst. The user provides a table of captured stock data. Your output is analysis only — no report, no recommendations. Use exactly these three sections:
## Data Overview
[1-2 sentences: what the table covers and key numbers]
## Trends and Findings
- [bullet 1]
- [bullet 2]
- [bullet 3]
## Conclusion
[1-2 sentences: analytical conclusion only]
Use only numbers from the table. Do not write a daily report or 30-day review; that is done by the next agent."""
out_agent2 = agent_run(role=ROLE_AGENT2, task=out_agent1, model=MODEL, output="text")

# 4. Agent 3: Report writing — two distinct reports (daily + 30-day review) ###################################
ROLE_AGENT3 = """You are a report writer. You receive an analysis (Data Overview, Trends, Conclusion). Your job is to write TWO separate reports — do not repeat or copy the analysis text.
## Daily Report
[Short report for the latest trading day: key price, volume, one-paragraph snapshot. Reader-facing.]
## 30-Day Review Report
[Separate report: past 30 days performance, trend summary, and a brief recommendation. Do not duplicate the Daily Report.]
Keep Daily Report and 30-Day Review Report clearly different in content and purpose."""
out_agent3 = agent_run(role=ROLE_AGENT3, task=out_agent2, model=MODEL, output="text")

# 5. Output ###################################
print("========== Agent 1 output (captured data) ==========")
print(out_agent1, "\n")
print("========== Agent 2 output (data analysis) ==========")
print(out_agent2, "\n")
print("========== Agent 3 output (daily report + 30-day review) ==========")
print(out_agent3)
print("========== End of workflow ==========")
