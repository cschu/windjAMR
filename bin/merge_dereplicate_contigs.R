
#!/usr/bin/env Rscript

library(dplyr)
library(stringr)

# -----------------------------
# Parse arguments
# -----------------------------
args <- commandArgs(trailingOnly = TRUE)

if (length(args) < 4) {
  stop("Usage:
  Rscript script.R combined_normed.tsv card_collapsed.tsv output.tsv non_normed1.tsv [non_normed2.tsv ...]")
}

combined_normed_file <- args[1]
card_file            <- args[2]
output_file          <- args[3]
non_normed_files     <- args[4:length(args)]

# -----------------------------
# Load data
# -----------------------------
card_collapsed     <- read.delim(card_file, stringsAsFactors = FALSE)
hamronized_normed  <- read.delim(combined_normed_file, comment.char = "#")

# Read all non-normed files and rbind immediately
non_normed_list <- lapply(non_normed_files, function(f) {
  df <- read.delim(f, stringsAsFactors = FALSE)
  if ("reference_accession" %in% colnames(df)) {
    df$reference_accession <- as.character(df$reference_accession)
  }
  return(df)
})

non_normed <- bind_rows(non_normed_list)

# Populate ARO in non-normed if reference_accession exists
if ("reference_accession" %in% colnames(non_normed)) {
  non_normed$ARO <- paste0("ARO:", non_normed$reference_accession)
}

# -----------------------------
# Harmonize columns and combine
# -----------------------------
# Identify all columns that exist in either df
all_cols <- union(colnames(hamronized_normed), colnames(non_normed))

# Add missing columns as NA
for (col in setdiff(all_cols, colnames(hamronized_normed))) hamronized_normed[[col]] <- NA
for (col in setdiff(all_cols, colnames(non_normed))) non_normed[[col]] <- NA

# Convert all columns in both data frames to character
hamronized_normed <- hamronized_normed %>% mutate(across(everything(), as.character))
non_normed         <- non_normed %>% mutate(across(everything(), as.character))

# Reorder columns
hamronized_normed <- hamronized_normed[, all_cols]
non_normed        <- non_normed[, all_cols]

# Then combine
combined_normed <- bind_rows(hamronized_normed, non_normed)

# Convert relevant numeric columns back to numeric
numeric_cols <- c("input_gene_start", "input_gene_stop") # add any others as needed
combined_normed[numeric_cols] <- lapply(combined_normed[numeric_cols], as.numeric)

# -----------------------------
# Update from CARD key
# -----------------------------
cols_to_update <- c(
  "ARO_name",
  "confers_resistance_to",
  "confers_resistance_to_names",
  "resistance_to_drug_classes",
  "resistance_to_drug_classes_names"
)

rows_to_update <- which(is.na(combined_normed$Cut_Off) |
                          combined_normed$Cut_Off != "Manual")

match_idx <- match(combined_normed$ARO[rows_to_update],
                   card_collapsed$ARO)

valid <- !is.na(match_idx)
update_rows <- rows_to_update[valid]
update_card_idx <- match_idx[valid]

for (col in cols_to_update) {
  if (col %in% colnames(combined_normed)) {
    combined_normed[update_rows, col] <-
      card_collapsed[[col]][update_card_idx]
  }
}

# -----------------------------
# Dereplication
# -----------------------------
merged_dereplicated <- combined_normed %>%
  filter(!is.na(ARO) & ARO != "" & ARO != "ARO:") %>%
  
  mutate(
    base_sequence_id = if_else(
      str_count(input_sequence_id, "_") == 2,
      str_replace(input_sequence_id,
                  "^([^_]+_[^_]+)_.*$",
                  "\\1"),
      input_sequence_id
    )
  ) %>%
  
  group_by(base_sequence_id) %>%
  mutate(n_hits = n()) %>%
  ungroup() %>%
  
  mutate(
    is_multi_hit = n_hits > 1,
    START_bin = ifelse(is_multi_hit,
                       round(input_gene_start / 100) * 100,
                       input_gene_start),
    END_bin   = ifelse(is_multi_hit,
                       round(input_gene_stop  / 100) * 100,
                       input_gene_stop)
  ) %>%
  
  group_by(base_sequence_id, ARO) %>%
  summarise(
    input_sequence_id = first(input_sequence_id),
    START_bin = paste(unique(START_bin), collapse = ","),
    END_bin   = paste(unique(END_bin), collapse = ","),
    across(
      !any_of(c("input_sequence_id",
                "base_sequence_id",
                "ARO",
                "START_bin",
                "END_bin")),
      ~ {
        vals <- unique(as.character(.x))
        if (length(vals) == 1) vals else paste(vals, collapse = ",")
      }
    ),
    .groups = "drop"
  ) %>%
  
  group_by(input_sequence_id) %>%
  mutate(conflict = {
    n <- n()
    out <- rep(NA_character_, n)
    if (n > 1) {
      for (i in seq_len(n - 1)) {
        for (j in seq((i + 1), n)) {
          start_i <- as.numeric(str_split(START_bin[i], ",")[[1]])
          end_i   <- as.numeric(str_split(END_bin[i], ",")[[1]])
          start_j <- as.numeric(str_split(START_bin[j], ",")[[1]])
          end_j   <- as.numeric(str_split(END_bin[j], ",")[[1]])
          
          if (any(pmax(0,
                       pmin(end_i, end_j) -
                       pmax(start_i, start_j) + 1) > 0) &&
              ARO[i] != ARO[j]) {
            out[i] <- "conflict"
            out[j] <- "conflict"
          }
        }
      }
    }
    out
  }) %>%
  ungroup() %>%
  select(-START_bin, -END_bin, -n_hits, -is_multi_hit)

# -----------------------------
# Write output
# -----------------------------
write.table(
  merged_dereplicated,
  file = output_file,
  sep = "\t",
  quote = FALSE,
  row.names = FALSE
)

