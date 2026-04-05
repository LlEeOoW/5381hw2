# HOMEWORK2_integrated_system.R
# Homework 2 — one script compiling three weekly labs:
#   • LAB_prompt_design (06_agents)     -> Part 1: multi-agent prompts + chain
#   • LAB_custom_rag_query (07_rag)     -> Part 2: CSV search + JSON + RAG queries (same 3 queries as 05_custom_csv_rag.R)
#   • LAB_multi_agent_with_tools (08)   -> Part 3: tool metadata + get_shortages + agent chain
#
# Run from anywhere:
#   Rscript 08_function_calling/HOMEWORK2_integrated_system.R
#
# Requires: Ollama running; models pulled (see MODEL below).
# Optional: 06_agents/.env with API_KEY=... for Alpha Vantage (else demo key).

# =============================================================================
# Repo root (parent of 08_function_calling)
# =============================================================================
args = commandArgs(trailingOnly = FALSE)
match = grep("^--file=", args)
if (length(match) > 0) {
  script_path = sub("^--file=", "", args[match])
  if (nzchar(script_path) && file.exists(script_path)) {
    ROOT = dirname(dirname(normalizePath(script_path)))
    setwd(ROOT)
  }
}

# =============================================================================
# Packages
# =============================================================================
suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(httr2)
  library(jsonlite)
  library(ollamar)
  library(purrr)
  library(lubridate)
  library(stringr)
})

if (!requireNamespace("knitr", quietly = TRUE)) {
  install.packages("knitr", repos = "https://cloud.r-project.org")
}

# =============================================================================
# Shared config
# =============================================================================
MODEL = "smollm2:1.7b"
source("08_function_calling/functions.R")

# Toggle parts if you only want to run one section (set FALSE to skip)
RUN_PART1_MULTI_AGENT = TRUE
RUN_PART2_RAG = TRUE
RUN_PART3_FUNCTION_CALLING = TRUE

cat("\n")
cat("================================================================================\n")
cat(" HOMEWORK 2 — Integrated system | wd:", getwd(), "\n")
cat("================================================================================\n\n")

# =============================================================================
# PART 1 — Multi-agent orchestration (Alpha Vantage -> 3 Ollama agents)
# =============================================================================
if (RUN_PART1_MULTI_AGENT) {
  cat("---------- PART 1: Multi-agent (stock data) ----------\n\n")

  if (file.exists("06_agents/.env")) readRenviron("06_agents/.env")
  API_KEY = Sys.getenv("API_KEY")
  if (!nzchar(API_KEY)) API_KEY = "demo"

  SYMBOL = "IBM"

  req = request("https://www.alphavantage.co/query") |>
    req_url_query(
      `function` = "TIME_SERIES_DAILY",
      symbol = SYMBOL,
      apikey = API_KEY
    ) |>
    req_method("GET")
  resp = req_perform(req)
  if (resp_status(resp) != 200) stop("Alpha Vantage request failed. Check API key and 06_agents/.env.")
  data = resp_body_json(resp)
  ts = data[["Time Series (Daily)"]]
  if (is.null(ts)) stop("No time series in Alpha Vantage response.")

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
  df_stock$volume = round(df_stock$volume, 0)

  out_agent1 = df_as_text(df_stock)

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

  ROLE_AGENT3 = "You are a report writer. You receive an analysis (Data Overview, Trends, Conclusion). Your job is to write TWO separate reports — do not repeat or copy the analysis text.
## Daily Report
[Short report for the latest trading day: key price, volume, one-paragraph snapshot. Reader-facing.]
## 30-Day Review Report
[Separate report: past 30 days performance, trend summary, and a brief recommendation. Do not duplicate the Daily Report.]
Keep Daily Report and 30-Day Review Report clearly different in content and purpose."

  out_agent3 = agent_run(role = ROLE_AGENT3, task = out_agent2, model = MODEL, output = "text")

  cat("========== Agent 1 (captured data, excerpt) ==========\n")
  cat(substr(out_agent1, 1, min(1200L, nchar(out_agent1))), if (nchar(out_agent1) > 1200) "\n... [truncated]\n" else "\n")
  cat("\n========== Agent 2 (analysis) ==========\n")
  cat(out_agent2, "\n\n")
  cat("========== Agent 3 (daily + 30-day reports) ==========\n")
  cat(out_agent3, "\n\n")
}

# =============================================================================
# PART 2 — RAG (custom CSV + search + Ollama)
# =============================================================================
if (RUN_PART2_RAG) {
  cat("---------- PART 2: RAG (CSV retrieval) ----------\n\n")

  DOCUMENT = "07_rag/data/custom_topics.csv"

  search = function(query, document) {
    df = read_csv(document, show_col_types = FALSE)
    q = tolower(query)
    tokens = unlist(strsplit(q, "\\s+"))
    tokens = tokens[tokens != ""]

    df2 = df %>%
      mutate(
        haystack = paste(tolower(Name), tolower(Category), tolower(Content), tolower(Keywords), sep = " ")
      )

    matches_idx = rep(FALSE, nrow(df2))
    for (tok in tokens) {
      matches_idx = matches_idx | str_detect(df2$haystack, tok)
    }

    matches = df2[matches_idx, c("Name", "Category", "Content", "Keywords"), drop = FALSE] %>%
      as_tibble() %>%
      slice_head(n = 5) %>%
      mutate(Content = substr(Content, 1, 450))

    matches_list = lapply(seq_len(nrow(matches)), function(i) {
      as.list(matches[i, , drop = FALSE])
    })

    jsonlite::toJSON(
      list(
        query = query,
        num_matches = nrow(matches),
        matches = matches_list
      ),
      auto_unbox = TRUE
    )
  }

  role_rag = paste0(
    "You are a technical assistant.\n",
    "The input to you is a JSON string with fields: query, num_matches, matches.\n",
    "Each element in matches is an object with fields: Name, Category, Content, Keywords.\n",
    "Rules:\n",
    "1) Do not repeat the JSON input.\n",
    "2) If num_matches is 0, output exactly: Not enough information found in the dataset.\n",
    "3) If num_matches > 0, use ONLY the information in matches[].Content and matches[].Category.\n",
    "4) Do not invent details that are not present in the retrieved Content.\n",
    "Output format (when num_matches > 0):\n",
    "# Answer\n",
    "One short paragraph (1-2 sentences).\n",
    "## Key points\n",
    "- Key point 1\n",
    "- Key point 2\n",
    "- Key point 3\n",
    "## Retrieved entries\n",
    "Retrieved entries: <comma-separated list of match Name values>\n",
    "Do not output anything else besides the markdown above.\n"
  )

  # Same multi-query loop as LAB `07_rag/05_custom_csv_rag.R` (LAB_custom_rag_query)
  queries = c(
    "manifest.json writeManifest",
    "TIME_SERIES_DAILY",
    "localhost:11434 /api/chat"
  )
  for (q in queries) {
    cat("============================================================\n")
    cat("Query:", q, "\n")
    retrieved_json = search(q, DOCUMENT)
    cat("Retrieved JSON (excerpt):\n")
    cat(substr(retrieved_json, 1, min(600L, nchar(retrieved_json))), if (nchar(retrieved_json) > 600) "...\n" else "\n")
    cat("\n--- LLM answer ---\n")
    ans = agent_run(role = role_rag, task = retrieved_json, model = MODEL, output = "text")
    cat(ans, "\n\n")
  }
}

# =============================================================================
# PART 3 — Function calling (FDA Drug Shortages API + tools + agents)
# =============================================================================
if (RUN_PART3_FUNCTION_CALLING) {
  cat("---------- PART 3: Function calling (FDA tool) ----------\n\n")

  get_shortages = function(category = "Psychiatry", limit = 500) {
    req = request("https://api.fda.gov/drug/shortages.json") |>
      req_headers(Accept = "application/json") |>
      req_method("GET") |>
      req_url_query(sort = "initial_posting_date:desc") |>
      req_url_query(search = paste0(
        'dosage_form:"Capsule"+status:"Current"+therapeutic_category:"', category, '"'
      )) |>
      req_url_query(limit = limit)

    resp = req |> req_perform()
    data = resp_body_json(resp)

    res = data$results
    if (is.null(res) || length(res) == 0L) {
      return(tibble(
        therapeutic_category = character(),
        generic_name = character(),
        update_type = character(),
        update_date = as.Date(character()),
        availability = character(),
        related_info = character()
      ))
    }

    processed_data = res |>
      map_dfr(~tibble(
        therapeutic_category = paste0(.x$therapeutic_category, collapse = ", "),
        generic_name = .x$generic_name,
        update_type = .x$update_type,
        update_date = .x$update_date,
        availability = .x$availability,
        related_info = .x$related_info,
      )) %>%
      mutate(update_date = lubridate::mdy(update_date))
    processed_data
  }

  categories = c(
    "Analgesia/Addiction", "Anesthesia", "Anti-Infective", "Antiviral", "Cardiovascular",
    "Dental", "Dermatology", "Endocrinology/Metabolism", "Gastroenterology", "Hematology",
    "Inborn Errors", "Medical Imaging", "Musculoskeletal", "Neurology", "Oncology",
    "Ophthalmology", "Other", "Pediatric", "Psychiatry", "Pulmonary/Allergy", "Renal",
    "Reproductive", "Rheumatology", "Total Parenteral Nutrition", "Transplant", "Urology"
  )

  tool_get_shortages = list(
    type = "function",
    "function" = list(
      name = "get_shortages",
      description = "Get data on drug shortages",
      parameters = list(
        type = "object",
        required = list("category", "limit"),
        properties = list(
          category = list(
            type = "string",
            description = paste0("the therapeutic category of the drug. Options are: ", paste(categories, collapse = ", "), ".")
          ),
          limit = list(type = "numeric", description = "the max number of results to return. Default is 500.")
        )
      )
    )
  )

  task = "Get data on drug shortages for the category Psychiatry"
  role1 = "I fetch information from the FDA Drug Shortages API"
  result1 = agent_run(
    role = role1, task = task, model = MODEL, output = "tools",
    tools = list(tool_get_shortages)
  )

  cat("--- Agent 1 (tool) -> head(result) ---\n")
  print(head(result1, 10L))

  role2 = paste(
    "You are a data analyst. The user lists FDA drug shortage lines (drug | update | availability).",
    "Reply with 3-6 bullet points summarizing patterns (which drugs, mostly revised or reverified, availability).",
    sep = " "
  )
  r1 = head(result1, 25)
  lines = with(r1, paste(generic_name, update_type, availability, sep = " | "))
  task2 = paste0("Records:\n", paste(lines, collapse = "\n"))
  result2 = agent_run(role = role2, task = task2, model = MODEL, output = "text", tools = NULL)

  cat("\n--- Agent 2 (analysis) ---\n")
  cat(result2, sep = "\n")

  role3 = paste(
    "You are a communications writer. Write a short press release (3-5 sentences)",
    "based only on the analysis paragraph you receive. Do not add facts not in the analysis.",
    sep = " "
  )
  result3 = agent_run(role = role3, task = result2, model = MODEL, output = "text", tools = NULL)

  cat("\n--- Agent 3 (press release) ---\n")
  cat(result3, sep = "\n")
  cat("\n")
}

cat("================================================================================\n")
cat(" Done.\n")
cat("================================================================================\n")
