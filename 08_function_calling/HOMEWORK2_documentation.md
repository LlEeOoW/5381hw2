# Homework 2 — System documentation (for .docx submission)

**GitHub repo (submission):** [LlEeOoW/5381hw2](https://github.com/LlEeOoW/5381hw2)

Copy the sections below into your Word document. Same content also appears under **Appendix → Documentation** in [`HOMEWORK2.md`](HOMEWORK2.md).

---

## 1. System architecture — agent roles and workflow

| Stage | What happens | Main script |
|-------|----------------|-------------|
| **Multi-agent** | Alpha Vantage daily prices → table text → **Agent 2** analyzes (overview / trends / conclusion) → **Agent 3** writes daily report + 30-day review. (Agent 1 output is the captured table, produced in code.) | [`06_agents/06_multi_agent_lab.R`](https://github.com/LlEeOoW/5381hw2/blob/main/06_agents/06_multi_agent_lab.R) |
| **RAG** | User query → **`search()`** on CSV → JSON of matches → **Ollama** answers with a fixed system prompt (grounded on retrieval). | [`07_rag/05_custom_csv_rag.R`](https://github.com/LlEeOoW/5381hw2/blob/main/07_rag/05_custom_csv_rag.R) |
| **Function calling** | **Agent 1** calls tool **`get_shortages`** (FDA API) → **Agent 2** summarizes lines of text → **Agent 3** short press-style text. | [`08_function_calling/04_multiple_agents_with_function_calling.R`](https://github.com/LlEeOoW/5381hw2/blob/main/08_function_calling/04_multiple_agents_with_function_calling.R) |
| **All-in-one (optional)** | Runs the three blocks above in one run from repo root. | [`08_function_calling/HOMEWORK2_integrated_system.R`](https://github.com/LlEeOoW/5381hw2/blob/main/08_function_calling/HOMEWORK2_integrated_system.R) |

---

## 2. RAG data source and search function

| Item | Detail |
|------|--------|
| **Data file** | [`07_rag/data/custom_topics.csv`](https://github.com/LlEeOoW/5381hw2/blob/main/07_rag/data/custom_topics.csv) |
| **Columns** | `Name`, `Category`, `Content`, `Keywords` — short notes (deployment, Ollama, APIs, RAG, etc.). |
| **`search(query, document)`** | Lowercase query, split into tokens; OR-match each token against a **haystack** string (concatenation of those columns); return up to **5** rows; truncate `Content`; output JSON `{ query, num_matches, matches }` for the LLM. |

---

## 3. Tool functions

| Name | Purpose | Parameters | Returns |
|------|---------|------------|---------|
| **`get_shortages`** (in-process R tool) | Query FDA open Drug Shortages API | `category` (therapeutic class), `limit` (max rows) | `tibble` of shortage records |
| **`summarize_dataset`** (MCP, optional) | Numeric summaries | `dataset_name`: `mtcars` or `iris` | JSON string (stats table) |
| **`filter_cars_by_mpg`** (MCP, optional) | Filter `mtcars` by mpg | `min_mpg` (number) | JSON (up to 15 rows) |

MCP tool definitions and HTTP handler: [`08_function_calling/mcp_plumber/plumber.R`](https://github.com/LlEeOoW/5381hw2/blob/main/08_function_calling/mcp_plumber/plumber.R).

---

## 4. Technical details

| Topic | Detail |
|-------|--------|
| **LLM** | [Ollama](https://ollama.com/) at `http://localhost:11434` (default). Models: e.g. `smollm2:135m`, `smollm2:1.7b` — see `MODEL` in each script. |
| **Alpha Vantage** | `API_KEY` in `06_agents/.env` (copy from [`06_agents/.env.example`](https://github.com/LlEeOoW/5381hw2/blob/main/06_agents/.env.example)). |
| **FDA API** | Public HTTPS, no key. |
| **MCP (local)** | Plumber POST `http://127.0.0.1:8000/mcp`; optional `CONNECT_API_KEY` in client — see [`mcp_plumber/testme.R`](https://github.com/LlEeOoW/5381hw2/blob/main/08_function_calling/mcp_plumber/testme.R). |
| **R packages** | `ollamar`, `httr2`, `dplyr`, `readr`, `jsonlite`, `purrr`, `lubridate`, `stringr`, `knitr`, `plumber`, … |
| **Layout** | `06_agents/`, `07_rag/`, `08_function_calling/` (includes `mcp_plumber/`, `mcp_fastapi/`). |

---

## 5. Usage instructions

1. **Clone:** `git clone https://github.com/LlEeOoW/5381hw2.git` and `cd 5381hw2`.
2. **Ollama:** Install Ollama; `ollama pull` the models your script uses.
3. **R packages:** Install missing packages when R errors, or run `install.packages(c("ollamar","httr2","dplyr",...))` as needed.
4. **Alpha Vantage:** Copy `06_agents/.env.example` → `06_agents/.env`, set `API_KEY=...`.
5. **Run (repo root):**
   - Integrated: `Rscript 08_function_calling/HOMEWORK2_integrated_system.R`
   - Multi-agent only: `Rscript 06_agents/06_multi_agent_lab.R`
   - RAG only: `Rscript 07_rag/05_custom_csv_rag.R`
   - Function calling only: `Rscript 08_function_calling/04_multiple_agents_with_function_calling.R`
6. **MCP (optional):** Start server: `Rscript 08_function_calling/mcp_plumber/runme.R`, then test: `Rscript 08_function_calling/mcp_plumber/testme.R` (set `MCP_SERVER` if not port 8000).

---

*Also see repository [`README.md`](https://github.com/LlEeOoW/5381hw2/blob/main/README.md) for quick links and commands.*
