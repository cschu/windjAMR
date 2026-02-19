#!/usr/bin/env Rscript

library(dplyr)
library(stringr)

# -----------------------------
# Parse arguments
# -----------------------------
args <- commandArgs(trailingOnly = TRUE)

if (length(args) < 5) {
  stop("Usage:
  Rscript script.R combined_normed.tsv card_collapsed.tsv deeparg_coords.tsv output.tsv non_normed1.tsv [non_normed2.tsv ...]")
}

combined_normed_file <- args[1]
card_file            <- args[2]
deeparg_coords_file  <- args[3]
output_file          <- args[4]
non_normed_files     <- args[5:length(args)]

# -----------------------------
# Load data
# -----------------------------
card_collapsed     <- read.delim(card_file, stringsAsFactors = FALSE)
hamronized_normed  <- read.delim(combined_normed_file, comment.char = "#")

# -----------------------------
# Patch deepARG coordinates
# -----------------------------
deeparg_coords <- read.delim(deeparg_coords_file, stringsAsFactors = FALSE)
# Expected columns: input_sequence_id, start, stop

# Validate expected columns are present
required_coord_cols <- c("input_sequence_id", "start", "stop")
if (!all(required_coord_cols %in% colnames(deeparg_coords))) {
  stop(paste(
    "deeparg_coords file is missing one or more required columns:",
    paste(setdiff(required_coord_cols, colnames(deeparg_coords)), collapse = ", ")
  ))
}

# Build a lookup keyed on input_sequence_id
coord_lookup <- deeparg_coords %>%
  select(input_sequence_id, start, stop) %>%
  distinct(input_sequence_id, .keep_all = TRUE)

# Identify rows in hamronized_normed whose input_sequence_id appears in the coord file
match_idx <- match(hamronized_normed$input_sequence_id, coord_lookup$input_sequence_id)
rows_to_patch <- which(!is.na(match_idx))

n_patched <- length(rows_to_patch)
if (n_patched == 0) {
  warning("No input_sequence_id values in combined_normed_file matched the deeparg_coords file. ",
          "Check that IDs are consistent between files.")
} else {
  message(sprintf("Patching coordinates for %d row(s) from deeparg_coords.", n_patched))
  hamronized_normed$input_gene_start[rows_to_patch] <-
    coord_lookup$start[match_idx[rows_to_patch]]
  hamronized_normed$input_gene_stop[rows_to_patch] <-
    coord_lookup$stop[match_idx[rows_to_patch]]
}

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


# Populate ARO in non-normed: use reference_accession if it looks like a real ARO number,
# otherwise fall back to matching gene_symbol against ARO_name in card_collapsed
if ("reference_accession" %in% colnames(non_normed)) {
  is_real_aro <- grepl("^\\d+$", non_normed$reference_accession)
  
  non_normed$ARO <- ifelse(
    is_real_aro,
    paste0("ARO:", non_normed$reference_accession),
    NA_character_
  )
  
  if ("gene_symbol" %in% colnames(non_normed)) {
    needs_aro <- which(is.na(non_normed$ARO) & !is.na(non_normed$gene_symbol))
    match_idx <- match(
      tolower(non_normed$gene_symbol[needs_aro]),
      tolower(card_collapsed$ARO_name)
    )
    non_normed$ARO[needs_aro[!is.na(match_idx)]] <-
      card_collapsed$ARO[match_idx[!is.na(match_idx)]]
  }
}

# -----------------------------
# Harmonize columns and combine
# -----------------------------
all_cols <- union(colnames(hamronized_normed), colnames(non_normed))

for (col in setdiff(all_cols, colnames(hamronized_normed))) hamronized_normed[[col]] <- NA
for (col in setdiff(all_cols, colnames(non_normed))) non_normed[[col]] <- NA

hamronized_normed <- hamronized_normed %>% mutate(across(everything(), as.character))
non_normed         <- non_normed %>% mutate(across(everything(), as.character))

hamronized_normed <- hamronized_normed[, all_cols]
non_normed        <- non_normed[, all_cols]

combined_normed <- bind_rows(hamronized_normed, non_normed)

numeric_cols <- c("input_gene_start", "input_gene_stop")
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
no_aro <- combined_normed %>%
  filter(is.na(ARO) | ARO == "" | ARO == "ARO:")

has_aro <- combined_normed %>%
  filter(!is.na(ARO) & ARO != "" & ARO != "ARO:")

merged_dereplicated <- has_aro %>%
  
  mutate(
    input_sequence_id_clean = str_replace(input_sequence_id, "\\s.*$", ""),
    base_sequence_id = if_else(
      str_count(input_sequence_id_clean, "_") == 2,
      str_replace(input_sequence_id_clean, "^([^_]+_[^_]+)_.*$", "\\1"),
      input_sequence_id_clean
    )
  ) %>%
  
  group_by(base_sequence_id) %>%
  mutate(n_hits = n()) %>%
  ungroup() %>%
  
  group_by(base_sequence_id, ARO) %>%
  summarise(
    input_sequence_id = first(input_sequence_id),
    gene_start        = first(input_gene_start),
    gene_stop         = first(input_gene_stop),
    across(
      !any_of(c("input_sequence_id", "base_sequence_id", "ARO",
                "gene_start", "gene_stop")),
      ~ {
        vals <- unique(as.character(.x))
        if (length(vals) == 1) vals else paste(vals, collapse = ",")
      }
    ),
    .groups = "drop"
  ) %>%
  
  # Reciprocal 50% overlap conflict detection
  group_by(base_sequence_id) %>%
  mutate(conflict = {
    n   <- n()
    out <- rep(NA_character_, n)
    if (n > 1) {
      for (i in seq_len(n - 1)) {
        for (j in seq(i + 1, n)) {
          
          # Skip if same ARO
          if (ARO[i] == ARO[j]) next
          
          len_i   <- gene_stop[i] - gene_start[i] + 1
          len_j   <- gene_stop[j] - gene_start[j] + 1
          overlap <- min(gene_stop[i], gene_stop[j]) -
            max(gene_start[i], gene_start[j]) + 1
          
          # Only count positive overlaps
          if (overlap <= 0) next
          
          # Reciprocal overlap: overlap must exceed 50% of BOTH gene lengths
          if ((overlap / len_i > 0.5) && (overlap / len_j > 0.5)) {
            out[i] <- "conflict"
            out[j] <- "conflict"
          }
        }
      }
    }
    out
  }) %>%
  ungroup() %>%
  select(-n_hits, -gene_start, -gene_stop)

final_output <- bind_rows(
  merged_dereplicated %>% mutate(across(all_of(numeric_cols), as.character)),
  no_aro             %>% mutate(across(all_of(numeric_cols), as.character))
)

# -----------------------------
# Write output
# -----------------------------
write.table(
  final_output,
  file = output_file,
  sep = "\t",
  quote = FALSE,
  row.names = FALSE
)