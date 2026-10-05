#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)

read_argument <- function(name, default = NULL) {
  index <- match(name, args)
  if (is.na(index) || index == length(args)) return(default)
  args[[index + 1L]]
}

input_path <- read_argument("--input", "data/raw_UTF-8.csv")
output_dir <- read_argument("--output", "data/processed")
seed <- as.integer(read_argument("--seed", "42"))

source(file.path("R", "pipeline.R"))
result <- prepare_datasets(input_path, output_dir, seed)

cat("Prepared leakage-safe splits:\n")
print(result$summary)
