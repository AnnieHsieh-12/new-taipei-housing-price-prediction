suppressPackageStartupMessages({
  library(dplyr)
  library(lubridate)
  library(randomForest)
  library(readr)
  library(RRF)
  library(stringr)
  library(tibble)
})

TARGET_COLUMN <- "單價元平方公尺"
TARGET_LOG_COLUMN <- "target_log"
TARGET_RAW_COLUMN <- "target_raw"

parse_floor_number <- function(value) {
  if (length(value) != 1L || is.na(value) || !nzchar(trimws(value))) {
    return(NA_real_)
  }

  text <- trimws(as.character(value))
  is_underground <- grepl("地下", text, fixed = TRUE)
  ascii_number <- str_extract(text, "[0-9]+")

  if (!is.na(ascii_number)) {
    result <- as.numeric(ascii_number)
  } else {
    chinese <- gsub("[^一二三四五六七八九十]", "", text)
    digits <- c("一" = 1, "二" = 2, "三" = 3, "四" = 4, "五" = 5,
                "六" = 6, "七" = 7, "八" = 8, "九" = 9)

    if (!nzchar(chinese)) {
      return(NA_real_)
    } else if (chinese == "十") {
      result <- 10
    } else if (grepl("十", chinese, fixed = TRUE)) {
      parts <- strsplit(chinese, "十", fixed = TRUE)[[1]]
      tens <- if (!nzchar(parts[1])) 1 else unname(digits[parts[1]])
      ones <- if (length(parts) < 2L || !nzchar(parts[2])) 0 else unname(digits[parts[2]])
      result <- tens * 10 + ones
    } else {
      result <- unname(digits[chinese])
    }
  }

  if (!is.finite(result)) return(NA_real_)
  if (is_underground) -abs(result) else abs(result)
}

parse_completion_year <- function(value) {
  if (length(value) != 1L || is.na(value) || !nzchar(trimws(value))) {
    return(NA_real_)
  }

  text <- gsub("／", "/", trimws(as.character(value)))
  year_text <- str_extract(text, "(?<![0-9])(19[0-9]{2}|20[0-9]{2})(?![0-9])")

  if (!is.na(year_text)) {
    year <- as.numeric(year_text)
  } else {
    digits <- gsub("[^0-9]", "", text)
    if (!nzchar(digits)) return(NA_real_)
    if (nchar(digits) <= 3L) {
      year <- as.numeric(digits) + 1911
    } else {
      year <- as.numeric(substr(digits, 1L, 4L))
    }
  }

  if (!is.finite(year) || year < 1900 || year > 2100) NA_real_ else year
}

safe_numeric <- function(data, column) {
  if (!column %in% names(data)) return(rep(NA_real_, nrow(data)))
  suppressWarnings(as.numeric(data[[column]]))
}

binary_indicator <- function(data, column, positive = "有") {
  if (!column %in% names(data)) return(rep(NA_real_, nrow(data)))
  values <- trimws(as.character(data[[column]]))
  ifelse(is.na(values) | !nzchar(values), NA_real_, as.numeric(values == positive))
}

extract_count <- function(values, label) {
  pattern <- paste0("(?<=", label, ")[0-9]+")
  suppressWarnings(as.numeric(str_extract(as.character(values), pattern)))
}

build_base_features <- function(raw) {
  raw <- raw %>%
    rename_with(~ trimws(gsub("\\s+", "_", .x))) %>%
    mutate(across(where(is.character), trimws))

  unnamed <- names(raw)[grepl("^Unnamed|^\\.\\.\\.[0-9]+$", names(raw))]
  if (length(unnamed)) raw <- select(raw, -all_of(unnamed))

  target_raw <- safe_numeric(raw, TARGET_COLUMN)
  trade_date <- if ("交易年月日" %in% names(raw)) {
    suppressWarnings(dmy(gsub("／", "/", raw[["交易年月日"]])))
  } else {
    rep(as.Date(NA), nrow(raw))
  }
  trade_year <- year(trade_date)

  completion_year <- if ("建築完成年月" %in% names(raw)) {
    vapply(raw[["建築完成年月"]], parse_completion_year, numeric(1))
  } else {
    rep(NA_real_, nrow(raw))
  }

  transaction_counts <- if ("交易筆棟數" %in% names(raw)) {
    as.character(raw[["交易筆棟數"]])
  } else {
    rep(NA_character_, nrow(raw))
  }

  features <- tibble(
    target_raw = target_raw,
    target_log = log1p(target_raw),
    緯度 = safe_numeric(raw, "緯度"),
    經度 = safe_numeric(raw, "經度"),
    屋齡 = pmax(0, trade_year - completion_year),
    交易年 = trade_year,
    交易月 = month(trade_date),
    土地筆數 = extract_count(transaction_counts, "土地"),
    建物筆數 = extract_count(transaction_counts, "建物"),
    車位筆數 = extract_count(transaction_counts, "車位"),
    總樓層數值 = if ("總樓層數" %in% names(raw)) {
      vapply(raw[["總樓層數"]], parse_floor_number, numeric(1))
    } else rep(NA_real_, nrow(raw)),
    移轉層次值 = if ("移轉層次" %in% names(raw)) {
      vapply(raw[["移轉層次"]], parse_floor_number, numeric(1))
    } else rep(NA_real_, nrow(raw)),
    有管理組織 = binary_indicator(raw, "有無管理組織"),
    有電梯 = binary_indicator(raw, "電梯"),
    有隔間 = binary_indicator(raw, "建物現況格局.隔間"),
    含車位交易 = if ("交易標的" %in% names(raw)) {
      as.numeric(grepl("車位", raw[["交易標的"]]))
    } else rep(NA_real_, nrow(raw))
  )

  direct_columns <- c(
    "土地移轉總面積平方公尺", "建物移轉總面積平方公尺", "車位移轉總面積平方公尺",
    "主建物面積", "附屬建物面積", "陽台面積", "建物現況格局.房",
    "建物現況格局.廳", "建物現況格局.衛", "人口密度", "性比例",
    "15歲以上不識字人口數", "15歲以上國中初職人口數", "原住民人口比率",
    "扶老比", "扶幼比", "扶養比", "原住民0-9歲人口數", "原住民10-19歲人口數",
    "原住民20-29歲人口數", "原住民30-39歲人口數", "原住民40-49歲人口數",
    "原住民50-59歲人口數", "原住民60-69歲人口數", "原住民70-79歲人口數",
    "mrt", "thsr", "mall", "lpg"
  )

  for (column in direct_columns) {
    features[[column]] <- safe_numeric(raw, column)
  }

  features %>% filter(is.finite(target_raw), target_raw > 0, is.finite(target_log))
}

split_rows <- function(data, seed = 42L) {
  stopifnot(nrow(data) >= 10L)
  set.seed(seed)
  shuffled <- sample(seq_len(nrow(data)))
  train_end <- floor(0.70 * nrow(data))
  valid_end <- train_end + floor(0.15 * nrow(data))

  list(
    train = data[shuffled[seq_len(train_end)], , drop = FALSE],
    valid = data[shuffled[seq.int(train_end + 1L, valid_end)], , drop = FALSE],
    test = data[shuffled[seq.int(valid_end + 1L, nrow(data))], , drop = FALSE]
  )
}

fit_numeric_preprocessor <- function(train, feature_names) {
  stats <- lapply(feature_names, function(feature) {
    values <- train[[feature]]
    values[!is.finite(values)] <- NA_real_
    median_value <- median(values, na.rm = TRUE)
    if (!is.finite(median_value)) median_value <- 0
    quartiles <- quantile(values, c(0.25, 0.75), na.rm = TRUE, names = FALSE)
    iqr <- quartiles[2] - quartiles[1]
    if (!all(is.finite(quartiles)) || !is.finite(iqr) || iqr == 0) {
      lower <- -Inf
      upper <- Inf
    } else {
      lower <- quartiles[1] - 1.5 * iqr
      upper <- quartiles[2] + 1.5 * iqr
    }
    list(median = median_value, lower = lower, upper = upper)
  })
  names(stats) <- feature_names
  stats
}

apply_numeric_preprocessor <- function(data, stats) {
  output <- data
  for (feature in names(stats)) {
    values <- output[[feature]]
    values[!is.finite(values)] <- NA_real_
    values <- pmin(pmax(values, stats[[feature]]$lower), stats[[feature]]$upper)
    values[is.na(values)] <- stats[[feature]]$median
    output[[feature]] <- values
  }
  output
}

fit_pca_group <- function(train, columns, components) {
  available <- intersect(columns, names(train))
  available <- available[vapply(train[available], function(x) sd(x) > 0, logical(1))]
  if (length(available) < 2L) return(NULL)
  model <- prcomp(train[available], center = TRUE, scale. = TRUE)
  list(model = model, columns = available, components = min(components, ncol(model$x)))
}

apply_pca_group <- function(data, specification, prefix) {
  if (is.null(specification)) return(data)
  scores <- predict(specification$model, newdata = data[specification$columns])
  for (index in seq_len(specification$components)) {
    data[[paste0(prefix, index)]] <- scores[, index]
  }
  select(data, -all_of(specification$columns))
}

select_features_rrf <- function(train, feature_names, seed = 42L, max_features = 20L) {
  x <- train[feature_names]
  keep <- vapply(x, function(values) sd(values) > 0, logical(1))
  x <- x[keep]
  if (!ncol(x)) stop("No non-constant predictors remain after preprocessing.")

  set.seed(seed)
  initial_rf <- randomForest(
    x = x,
    y = train[[TARGET_LOG_COLUMN]],
    ntree = 500,
    mtry = max(1L, floor(sqrt(ncol(x)))),
    importance = TRUE
  )
  importance <- randomForest::importance(initial_rf, type = 1)[, 1]
  importance[!is.finite(importance)] <- 0
  shifted <- importance - min(importance)
  normalized <- if (max(shifted) > 0) shifted / max(shifted) else rep(0, length(shifted))
  regularization <- 0.5 + 0.5 * normalized

  set.seed(seed)
  rrf <- RRF(
    x = as.matrix(x),
    y = train[[TARGET_LOG_COLUMN]],
    flagReg = 1,
    coefReg = regularization,
    ntree = 700,
    mtry = max(1L, floor(sqrt(ncol(x))))
  )
  rrf_importance <- RRF::importance(rrf)[, 1]
  ranking <- tibble(
    feature = names(rrf_importance),
    importance = as.numeric(rrf_importance)
  ) %>% arrange(desc(importance))

  selected <- ranking %>%
    filter(is.finite(importance), importance > 0) %>%
    slice_head(n = max_features) %>%
    pull(feature)

  if (!length(selected)) {
    selected <- ranking %>% slice_head(n = min(max_features, nrow(ranking))) %>% pull(feature)
  }
  list(selected = selected, ranking = ranking)
}

prepare_datasets <- function(input_path, output_dir, seed = 42L) {
  if (!file.exists(input_path)) stop("Input CSV not found: ", input_path)
  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

  raw <- read_csv(input_path, guess_max = 100000, show_col_types = FALSE)
  base <- build_base_features(raw)
  splits <- split_rows(base, seed)

  feature_names <- setdiff(names(base), c(TARGET_LOG_COLUMN, TARGET_RAW_COLUMN))
  stats <- fit_numeric_preprocessor(splits$train, feature_names)
  splits <- lapply(splits, apply_numeric_preprocessor, stats = stats)

  socioeconomic <- c("人口密度", "性比例", "15歲以上不識字人口數", "15歲以上國中初職人口數")
  indigenous <- c(
    "原住民0-9歲人口數", "原住民10-19歲人口數", "原住民20-29歲人口數",
    "原住民30-39歲人口數", "原住民40-49歲人口數", "原住民50-59歲人口數",
    "原住民60-69歲人口數", "原住民70-79歲人口數"
  )
  socioeconomic_pca <- fit_pca_group(splits$train, socioeconomic, 2L)
  indigenous_pca <- fit_pca_group(splits$train, indigenous, 1L)

  splits <- lapply(splits, apply_pca_group, specification = socioeconomic_pca, prefix = "社經_PC")
  splits <- lapply(splits, apply_pca_group, specification = indigenous_pca, prefix = "原住民_PC")

  candidate_features <- setdiff(names(splits$train), c(TARGET_LOG_COLUMN, TARGET_RAW_COLUMN))
  selection <- select_features_rrf(splits$train, candidate_features, seed)
  output_columns <- c(selection$selected, TARGET_LOG_COLUMN, TARGET_RAW_COLUMN)
  splits <- lapply(splits, function(data) select(data, all_of(output_columns)))

  for (name in names(splits)) {
    write_csv(splits[[name]], file.path(output_dir, paste0(name, ".csv")))
  }
  write_csv(selection$ranking, file.path(output_dir, "feature_selection.csv"))
  write_lines(selection$selected, file.path(output_dir, "selected_features.txt"))

  summary <- tibble(
    split = names(splits),
    rows = vapply(splits, nrow, integer(1)),
    predictors = length(selection$selected),
    seed = as.integer(seed)
  )
  write_csv(summary, file.path(output_dir, "split_summary.csv"))
  invisible(list(splits = splits, selection = selection, summary = summary))
}
