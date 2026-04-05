# Homework 2 — AI agent system (multi-agent, RAG, tools)

Course submission: runnable R scripts. Run from **repository root** (parent of `06_agents`, `07_rag`, `08_function_calling`).

## Required GitHub links (functional)

| Component | File on `main` |
|-----------|----------------|
| **Multi-agent orchestration** | [`06_agents/06_multi_agent_lab.R`](https://github.com/LlEeOoW/5381hw2/blob/main/06_agents/06_multi_agent_lab.R) |
| **RAG implementation** | [`07_rag/05_custom_csv_rag.R`](https://github.com/LlEeOoW/5381hw2/blob/main/07_rag/05_custom_csv_rag.R) |
| **Function calling / tool definitions** | [`08_function_calling/04_multiple_agents_with_function_calling.R`](https://github.com/LlEeOoW/5381hw2/blob/main/08_function_calling/04_multiple_agents_with_function_calling.R) · [`08_function_calling/functions.R`](https://github.com/LlEeOoW/5381hw2/blob/main/08_function_calling/functions.R) (`agent`, `agent_run`, tool execution) |
| **Main integrated system** (all three labs in one script) | [`08_function_calling/HOMEWORK2_integrated_system.R`](https://github.com/LlEeOoW/5381hw2/blob/main/08_function_calling/HOMEWORK2_integrated_system.R) |

## Quick run

- **Integrated:** `Rscript 08_function_calling/HOMEWORK2_integrated_system.R`
- **Multi-agent only:** `cd` to repo root, then `Rscript 06_agents/06_multi_agent_lab.R` (uses `06_agents/.env` for Alpha Vantage `API_KEY` if present)
- **RAG only:** `Rscript 07_rag/05_custom_csv_rag.R`
- **Function calling only:** `Rscript 08_function_calling/04_multiple_agents_with_function_calling.R`

## Dependencies

- [Ollama](https://ollama.com/) with models referenced in scripts (e.g. `smollm2:1.7b`, `smollm2:135m`)
- R packages: `ollamar`, `httr2`, `dplyr`, `readr`, `jsonlite`, `purrr`, `lubridate`, `stringr`, `knitr`, etc.

## Data

- RAG CSV: [`07_rag/data/custom_topics.csv`](07_rag/data/custom_topics.csv)
