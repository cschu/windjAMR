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
card_collapsed    <- read.delim(card_file, stringsAsFactors = FALSE)
hamronized_normed <- read.delim(combined_normed_file, comment.char = "#")

# Read all non-normed files and rbind immediately
non_normed_list <- lapply(non_normed_files, function(f) {
  
  # If file is completely empty (0 bytes), return NULL
  if (file.info(f)$size == 0) {
    message(paste("Skipping empty file:", f))
    return(NULL)
  }
  
  df <- read.delim(f, stringsAsFactors = FALSE)
  
  # If file has header but 0 rows, keep it (bind_rows handles this fine)
  if (nrow(df) == 0) {
    message(paste("File has header but no rows:", f))
  }
  
  if ("reference_accession" %in% colnames(df)) {
    df$reference_accession <- as.character(df$reference_accession)
  }
  
  return(df)
})

# Remove NULLs before binding
non_normed_list <- Filter(Negate(is.null), non_normed_list)

# If all files were empty, create empty df
if (length(non_normed_list) == 0) {
  non_normed <- data.frame()
} else {
  non_normed <- bind_rows(non_normed_list)
}

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
non_normed        <- non_normed        %>% mutate(across(everything(), as.character))

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

valid       <- !is.na(match_idx)
update_rows <- rows_to_update[valid]
update_card_idx <- match_idx[valid]

for (col in cols_to_update) {
  if (col %in% colnames(combined_normed)) {
    combined_normed[update_rows, col] <-
      card_collapsed[[col]][update_card_idx]
  }
}

# -----------------------------
# Derive base_sequence_id
# -----------------------------
# For the non-normed (RGI) rows: input_sequence_id has the format
#   "k141_1625402_9 # 6236 # 9385 # -1 # ID=..."
# Extract everything before the first " # " as the base_sequence_id.
#
# For the normed rows: input_sequence_id is already a plain contig name,
# so use it as-is (str_extract returns the whole string when there is no
# " # " present, because the fallback pattern matches the full string).

combined_normed <- combined_normed %>%
  mutate(
    base_sequence_id = if_else(
      str_detect(input_sequence_id, " # "),
      str_extract(input_sequence_id, "^[^ ]+(?= # )"),  # everything before first " # "
      input_sequence_id                                  # plain id — use as-is
    )
  )

# -----------------------------
# Dereplication
# -----------------------------
merged_dereplicated <- combined_normed %>%
  filter(!is.na(ARO) & ARO != "" & ARO != "ARO:") %>%
  
  # Step 1: merge rows that share both base_sequence_id AND ARO,
  # comma-separating any non-identical values across columns.
  group_by(base_sequence_id, ARO) %>%
  summarise(
    input_sequence_id = first(input_sequence_id),
    across(
      !any_of(c("input_sequence_id", "base_sequence_id", "ARO")),
      ~ {
        vals <- unique(as.character(.x))
        vals <- vals[!is.na(vals)]
        if (length(vals) == 0) NA_character_
        else if (length(vals) == 1) vals
        else paste(vals, collapse = ",")
      }
    ),
    .groups = "drop"
  ) %>%
  
  # Step 2: flag conflicts — rows that share base_sequence_id but differ in ARO.
  group_by(base_sequence_id) %>%
  mutate(
    conflict = if_else(n() > 1, "conflict", NA_character_)
  ) %>%
  ungroup()

# -----------------------------
# Write output
# -----------------------------
write.table(
  merged_dereplicated,
  file      = output_file,
  sep       = "\t",
  quote     = FALSE,
  row.names = FALSE
)