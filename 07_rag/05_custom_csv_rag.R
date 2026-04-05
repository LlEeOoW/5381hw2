# 05_custom_csv_rag.R
# Custom CSV RAG workflow: create/search over a CSV dataset and answer with Ollama.

# Load libraries
library(dplyr)
library(readr)
library(jsonlite)
library(ollamar)

# Helper wrappers (agent_run, df_as_text, etc.)
source("07_rag/functions.R")

if (!requireNamespace("stringr", quietly = TRUE)) {
  install.packages("stringr", repos = "https://cloud.r-project.org")
}

# =============================================================================
# Configuration
# =============================================================================
MODEL = "smollm2:135m"  # small model for faster runs
PORT = 11434
OLLAMA_HOST = paste0("http://localhost:", PORT)

DOCUMENT = "07_rag/data/custom_topics.csv"

# =============================================================================
# Task 2: Implement Your Search Function
# =============================================================================
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
    matches_idx = matches_idx | stringr::str_detect(df2$haystack, tok)
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

# =============================================================================
# Test the search function
# =============================================================================
cat("=== Search test: manifest.json ===\n")
cat(search("manifest.json", DOCUMENT), "\n\n")

# =============================================================================
# Task 3: Build Your RAG Query Workflow
# =============================================================================
role = paste0(
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

queries = c(
  "manifest.json writeManifest",
  "TIME_SERIES_DAILY",
  "localhost:11434 /api/chat"
)

for (q in queries) {
  cat("============================================================\n")
  cat("Query:", q, "\n")
  retrieved_json = search(q, DOCUMENT)
  cat("Retrieved JSON:\n")
  cat(retrieved_json, "\n\n")
  result = agent_run(role = role, task = retrieved_json, model = MODEL, output = "text")
  cat(result, "\n")
}

# =============================================================================
# End of script
# =============================================================================

