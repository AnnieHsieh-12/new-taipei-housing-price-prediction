# New Taipei City Housing Price Prediction

An independent data science project by Pei-Ju Hsieh that models transaction-level housing prices in New Taipei City. The project focuses on reproducible preprocessing, leakage-safe feature selection, and a comparison of linear and tree-based regression models.

## Project status

This repository is the cleaned, portable version of a 2025 exploratory analysis. The original transaction-level dataset is private and is not included. Historical metrics were not copied into this repository because the earlier workflow fitted preprocessing and feature selection before the train-validation-test split. Run the revised pipeline to generate comparable metrics without that leakage.

## Research question

How accurately can housing unit prices be estimated from property characteristics, transaction attributes, location, transportation proximity, and area-level demographic indicators?

The target is `log1p(單價元平方公尺)`. Results are reported in both log space and the original unit-price scale.

## Method

1. Parse Taiwan real-estate fields, including Chinese floor numbers, transaction counts, and building completion years.
2. Split records into 70% training, 15% validation, and 15% test sets before any learned preprocessing.
3. Fit outlier limits, median imputation, PCA, and RRF feature selection on the training set only.
4. Compare Elastic Net, Ridge, Random Forest, and XGBoost on the same fixed splits.
5. Use validation data for XGBoost early stopping and reserve the test set for final comparison.

## Verified results

The revised pipeline completed successfully on 14,087 valid transactions with seed 42. It used 9,860 training records, 2,113 validation records, 2,114 test records, and 20 training-selected predictors.

| Model | Test log-RMSE | Test R² | Test MAPE |
|---|---:|---:|---:|
| XGBoost | 0.205 | 0.758 | 13.6% |
| Random Forest | 0.215 | 0.733 | 14.0% |
| Elastic Net | 0.276 | 0.562 | 21.2% |
| Ridge | 0.276 | 0.562 | 21.2% |

These figures describe one reproducible random split. They are not evidence of future-year, out-of-region, or production performance. Full-precision results are stored in `results/model_scores.csv`.

## Repository structure

```text
R/pipeline.R              Data preparation and training-only feature selection
scripts/prepare_data.R    Command-line adapter for the R pipeline
python/train_models.py    Model training and aggregate evaluation
tests/                    Parser and metric checks
data/README.md            Private-data placement and disclosure rules
results/                  Generated aggregate metrics
```

## Reproduce locally

Prerequisites: R 4.4 or later, Python 3.10 or later, and the private UTF-8 dataset.

Required R packages:

```r
install.packages(c("dplyr", "lubridate", "randomForest", "readr", "RRF", "stringr", "tibble"))
```

Set up Python once:

```bash
make setup
```

Place the private CSV at `data/raw_UTF-8.csv`, then run:

```bash
make run
```

To use a file stored elsewhere:

```bash
make run DATA="/absolute/path/to/private-data.csv"
```

Aggregate metrics are written to `results/model_scores.csv`; row-level prepared data remain under the ignored `data/` directory.

## Reproducibility safeguards

- No absolute user-specific paths are stored in the code.
- Raw and processed row-level data are ignored by Git.
- The random seed is configurable and recorded with the split summary.
- Target values are never imputed, capped, or used as predictors.
- PCA, imputation, outlier limits, and RRF selection are fitted using training data only.

## Limitations

The random split estimates interpolation performance within the available period and geography; it does not establish future-year or out-of-region performance. Area-level variables may also repeat across transactions. A temporal or grouped spatial holdout would be required before making deployment claims.

## Author

Pei-Ju Hsieh — independent project covering data preparation, feature engineering, model evaluation, and repository implementation.

## License

No license has been selected yet. The source dataset is excluded and cannot be redistributed.
