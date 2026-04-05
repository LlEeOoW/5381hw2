# 05_two_agent_workflow.R
# Two-agent workflow: Agent 1 (raw data -> summary), Agent 2 (summary -> formatted output).
# Pairs with 03_agents.R (3-stage) and 05_two_agent_workflow.py.

# Set working directory to script location so source("functions.R") is found
args = commandArgs(trailingOnly = FALSE)
match = grep("^--file=", args)
if (length(match) > 0) {
  script_path = sub("^--file=", "", args[match])
  if (nzchar(script_path) && file.exists(script_path)) {
    setwd(dirname(normalizePath(script_path)))
  }
}

# Load packages
if (!requireNamespace("ollamar", quietly = TRUE)) {
  install.packages("ollamar", repos = "https://cloud.r-project.org")
}
library(dplyr)
library(httr2)
library(jsonlite)
library(ollamar)
library(purrr)
library(lubridate)

source("functions.R")

# Model (pull with: ollama pull smollm2:135m if 404)
MODEL = "smollm2:135m"

# =============================================================================
# Data: same as 03_agents — fetch and convert to text for Agent 1
# =============================================================================
input = list(category = "Psychiatry")
data = get_shortages(category = input$category, limit = 500)
stat = data %>%
  group_by(generic_name) %>%
  filter(update_date == max(update_date)) %>%
  filter(availability == "Unavailable") %>%
  ungroup()
raw_data_text = df_as_text(stat)

# =============================================================================
# Agent 1: Takes raw data and produces a summary
# Input: raw_data_text  ->  Output: summary_text
# =============================================================================
role_agent1 = "You are a data analyst. Your job is to summarize the following drug shortage data in 3-5 short sentences. Include: (1) how many distinct drugs are listed, (2) which drug names appear, (3) any dates or availability notes. Be concise and factual."
summary_text = agent_run(role = role_agent1, task = raw_data_text, model = MODEL, output = "text")

# =============================================================================
# Agent 2: Takes the summary and produces formatted output
# Input: summary_text (Agent 1 output)  ->  Output: formatted report
# =============================================================================
role_agent2 = "You are a report writer. Turn the following summary into a short, formatted report. Use a clear title, bullet points for key facts, and end with one sentence recommendation for readers. Use markdown (headings, bullets)."
formatted_output = agent_run(role = role_agent2, task = summary_text, model = MODEL, output = "text")

# =============================================================================
# Verify: show how information passed between agents
# =============================================================================
cat("=== Raw data (input to Agent 1) [first 500 chars] ===\n")
cat(substr(raw_data_text, 1, 500), "\n\n")
cat("=== Agent 1 output (summary -> input to Agent 2) ===\n")
cat(summary_text, "\n\n")
cat("=== Agent 2 output (formatted report) ===\n")
cat(formatted_output, "\n")
cat("[Done] Two-agent workflow: raw -> summary -> formatted.\n")
