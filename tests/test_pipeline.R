source(file.path("R", "pipeline.R"))

stopifnot(parse_floor_number("十二層") == 12)
stopifnot(parse_floor_number("地下二層") == -2)
stopifnot(parse_floor_number("15層") == 15)
stopifnot(is.na(parse_floor_number(NA_character_)))

stopifnot(parse_completion_year("29/9/1983") == 1983)
stopifnot(parse_completion_year("民國99年") == 2010)
stopifnot(is.na(parse_completion_year("")))

sample_data <- tibble::tibble(
  單價元平方公尺 = c(100000, 120000, 110000, 90000, 130000, 125000, 105000, 98000, 115000, 108000),
  交易年月日 = rep("2/3/2022", 10),
  建築完成年月 = rep("29/9/1983", 10),
  緯度 = seq(25.0, 25.09, length.out = 10),
  經度 = seq(121.4, 121.49, length.out = 10)
)

features <- build_base_features(sample_data)
stopifnot(nrow(features) == 10)
stopifnot(all(features$屋齡 == 39))
stopifnot(all(is.finite(features$target_log)))

splits <- split_rows(features, seed = 42)
stopifnot(nrow(splits$train) == 7)
stopifnot(nrow(splits$valid) == 1)
stopifnot(nrow(splits$test) == 2)

repeated_splits <- split_rows(features, seed = 42)
stopifnot(identical(splits, repeated_splits))

preprocessing_train <- tibble::tibble(example = c(1, 2, 3))
preprocessing_valid <- tibble::tibble(example = c(NA_real_, 100))
preprocessing_stats <- fit_numeric_preprocessor(preprocessing_train, "example")
processed_valid <- apply_numeric_preprocessor(preprocessing_valid, preprocessing_stats)
stopifnot(identical(processed_valid$example, c(2, 4)))

cat("R pipeline tests passed.\n")
