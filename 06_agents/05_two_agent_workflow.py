# 05_two_agent_workflow.py
# Two-agent workflow: Agent 1 (raw data -> summary), Agent 2 (summary -> formatted output).
# Pairs with 03_agents.py (3-stage) and 05_two_agent_workflow.R.

# 0. SETUP ###################################

import os
_script_dir = os.path.dirname(os.path.abspath(__file__))
os.chdir(_script_dir)

import pandas as pd
from functions import agent_run, get_shortages, df_as_text

# 1. CONFIGURATION ###################################
MODEL = "smollm2:135m"

# 2. DATA: same as 03_agents — fetch and convert to text for Agent 1 ###################################
input_category = {"category": "Psychiatry"}
data = get_shortages(category=input_category["category"], limit=500)
stat = (
    data
    .groupby("generic_name")
    .apply(lambda x: x.loc[x["update_date"].idxmax()], include_groups=False)
    .reset_index(drop=True)
    .query("availability == 'Unavailable'")
)
raw_data_text = df_as_text(stat)

# 3. AGENT 1: Takes raw data and produces a summary ###################################
# Input: raw_data_text  ->  Output: summary_text
role_agent1 = (
    "You are a data analyst. Your job is to summarize the following drug shortage data "
    "in 3-5 short sentences. Include: (1) how many distinct drugs are listed, "
    "(2) which drug names appear, (3) any dates or availability notes. Be concise and factual."
)
summary_text = agent_run(role=role_agent1, task=raw_data_text, model=MODEL, output="text")

# 4. AGENT 2: Takes the summary and produces formatted output ###################################
# Input: summary_text (Agent 1 output)  ->  Output: formatted report
role_agent2 = (
    "You are a report writer. Turn the following summary into a short, formatted report. "
    "Use a clear title, bullet points for key facts, and end with one sentence recommendation "
    "for readers. Use markdown (headings, bullets)."
)
formatted_output = agent_run(role=role_agent2, task=summary_text, model=MODEL, output="text")

# 5. VERIFY: show how information passed between agents ###################################
print("=== Raw data (input to Agent 1) [first 500 chars] ===")
print(raw_data_text[:500], "\n")
print("=== Agent 1 output (summary -> input to Agent 2) ===")
print(summary_text, "\n")
print("=== Agent 2 output (formatted report) ===")
print(formatted_output)
print("\n[Done] Two-agent workflow: raw -> summary -> formatted.")
