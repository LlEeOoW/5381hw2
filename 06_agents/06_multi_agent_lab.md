# Multi-Agent Lab: Alpha Vantage Case

This lab implements a **3-agent workflow** using **Alpha Vantage** daily stock data and local **Ollama** for LLM calls. Each agent has a clear role, and outputs are chained so that Agent 1’s result becomes Agent 2’s input, and Agent 2’s result becomes Agent 3’s input.

---

## Task 1: Multi-Agent System Design

### Workflow (information flow)

```
[Alpha Vantage API]
       |
       v
[Raw daily table: date, open, high, low, close, volume]  -->  Agent 1 (Summarizer)
       |                                                              |
       |                                                              v
       |                                                    [Bullet-point summary:
       |                                                     symbol, N days, range,
       |                                                     key stats]
       |                                                              |
       |                                                              v
       |                                                    Agent 2 (Report Writer)
       |                                                              |
       |                                                              v
       |                                                    [Structured report:
       |                                                     ## Overview
       |                                                     ## Key Findings
       |                                                     ## Data Source]
       |                                                              |
       |                                                              v
       |                                                    Agent 3 (Formatter)
       |                                                              |
       |                                                              v
       |                                                    [Final alert:
       |                                                     [MARKET UPDATE]
       |                                                     TITLE + bullets + Recommendation]
       v
  (script output: Agent 1 → Agent 2 → Agent 3)
```

### Agent roles

| Agent | Primary function | Input | Output |
|-------|------------------|--------|--------|
| **Agent 1 (Summarizer)** | Turn the raw daily price table into a short factual summary. | Raw markdown table (date, open, high, low, close, volume). | Bullet-point summary: symbol, number of days, date range, lowest/highest/latest close, average volume. |
| **Agent 2 (Report Writer)** | Turn the summary into a structured report. | Agent 1’s bullet summary. | Markdown report with sections: **Overview**, **Key Findings**, **Data Source** (Alpha Vantage API). |
| **Agent 3 (Formatter)** | Turn the report into a brief, fixed-format market update. | Agent 2’s report. | First line `[MARKET UPDATE]`, then ALL CAPS title, 3–5 bullets, one-sentence `Recommendation: ...`. |

---

## Task 2: System Prompts

Each agent’s **system prompt** specifies:

- **Role**: e.g. “data summarizer for stock/market data”, “report writer”, “formatter”.
- **Output format**: bullets, section headers, required first line, length.
- **Constraints**: use only information from the input; no speculation; no invented facts.

### Agent 1 (Summarizer)

- **Role:** Data summarizer for stock/market data.
- **Format:** Bullet points only. First line: “Symbol: [symbol]. Number of days: N. Date range: …”. Then key stats (lowest/highest/latest close, average volume).
- **Constraints:** Only numbers and dates from the data; no speculation; 5–8 bullets max.

### Agent 2 (Report Writer)

- **Role:** Report writer.
- **Format:** Markdown with exactly: `## Overview` (2–3 sentences), `## Key Findings` (bullet list), `## Data Source` (one line: Alpha Vantage API).
- **Constraints:** Use only information from the summary; professional, neutral language.

### Agent 3 (Formatter)

- **Role:** Formatter for a brief market update.
- **Format:** First line `[MARKET UPDATE]`; then one ALL CAPS title (max 60 chars); 3–5 bullets; end with `Recommendation: ...` (one sentence).
- **Constraints:** Do not invent facts; use only content from the report; one short recommendation sentence.

---

## Task 3: Setup and Run

### 1. API key (Alpha Vantage)

- Get a free key: [Alpha Vantage API Key](https://www.alphavantage.co/support/#api-key).
- In `06_agents`, copy `.env.example` to `.env`:
  ```bash
  cd 06_agents
  copy .env.example .env
  ```
- Edit `.env` and set:
  ```env
  API_KEY=your_actual_alpha_vantage_key
  ```
- Do **not** commit `.env` (it is listed in `06_agents/.gitignore`).

You can use the same key as in `03_query_ai`; this lab only needs `API_KEY` in `06_agents/.env`.

### 2. Ollama and model

- Install and start [Ollama](https://ollama.com).
- Pull the model used in the script (e.g. `smollm2:135m`):
  ```bash
  ollama pull smollm2:135m
  ```

### 3. Run the workflow

**R:**

```bash
cd 06_agents
Rscript 06_multi_agent_lab.R
```

**Python:**

```bash
cd 06_agents
python 06_multi_agent_lab.py
```

You should see three blocks of output: Agent 1 (summary), Agent 2 (report), Agent 3 (formatted alert).

### 4. Iterate on prompts

- If an agent’s output is too vague: add “Include at least N bullets” or repeat the required section names.
- If the model ignores format: put the format requirement in the **first line** of the system prompt.
- If there is hallucination: strengthen “Use only facts from the input” and “Do not add information not in the summary/report.”

---

## Prompt Design Notes

- **Explicit format** (bullets, section headers, `[MARKET UPDATE]`) helps the model follow structure.
- **Constraints** (“use only facts from the data/summary/report”) reduce hallucination across the chain.
- **Agent chaining:** Each agent’s output is passed as the next agent’s **user message**; no extra parsing.
- **Iteration:** Run once, check each output, then tighten the prompt for the agent that misbehaves.

---

## Reference files

- `02_using_ollamar.R` / `02_using_ollama.py` — system prompts and chat.
- `03_agents.R` / `03_agents.py` — multi-agent workflow (FDA shortages).
- `04_rules.R` / `04_rules.yaml` — rules and structure.
- `functions.R` / `functions.py` — `agent_run()`, `df_as_text()`, etc.

---

## File overview

| File | Purpose |
|------|--------|
| `06_multi_agent_lab.R` | R script: fetch Alpha Vantage → 3 agents → print outputs. |
| `06_multi_agent_lab.py` | Python script: same workflow. |
| `06_multi_agent_lab.md` | This document (workflow, prompts, setup, iteration). |
| `.env.example` | Template for `API_KEY`; copy to `.env` and add your key. |
| `.gitignore` | Excludes `.env` from version control. |
