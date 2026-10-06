# New Taipei City Housing Price Prediction

This project estimates residential transaction prices in New Taipei City from property, transaction, location, transport, and area-level demographic variables. R handles data preparation and feature selection; Python trains and evaluates Elastic Net, Ridge, Random Forest, and XGBoost models. The repository provides a reproducible analysis workflow, but not a fully locked, bit-for-bit reproducible software environment.

## Project overview

- **Target:** `log1p(單價元平方公尺)`, the natural logarithm of unit price in New Taiwan dollars per square meter after adding one
- **Original data:** 14,092 transaction records and 199 variables
- **Analysis sample:** 14,087 records with a valid positive target
- **Split:** 70% training, 15% validation, and 15% test
- **Feature selection:** Regularized Random Forest, fitted on the training split

## Data source and availability

The row-level dataset is not included because it contains address-level locations, exact coordinates, transaction identifiers, and other transaction-level information. Raw data, processed records, and model-ready splits are excluded by `.gitignore`; the repository contains code, documentation, and aggregate results only.

The repository does not currently document the original public or licensed source, the transaction coverage period, or whether all 199 variables came from one dataset or were assembled from several sources. These details should be added once they can be confirmed from the original data documentation.

Users with access to the same data can place the UTF-8 CSV at `data/raw_UTF-8.csv` or pass another local path to the pipeline. The preparation code expects a target column named `單價元平方公尺` and uses optional predictors when they are available.

## Method

### Feature engineering

The R pipeline converts the mixed-format source fields into numeric predictors. It parses common floor descriptions, including underground and 十-based forms; extracts land, building, and parking counts; derives transaction date and building-age features; encodes selected binary housing attributes; and retains available property, geographic, proximity, and demographic variables.

The source column names `thsr`, `mrt`, `mall`, and `lpg` appear among the selected features, but their definitions and units are not documented in the repository. They should not be interpreted more specifically until the original data dictionary is available.

### Train/validation/test preprocessing

Records are split before data-dependent preprocessing. Median imputation, interquartile-range outlier limits, grouped demographic PCA, and Regularized Random Forest feature selection are fitted on the training data and then applied unchanged to validation and test data. The target is not imputed, capped, or used as a predictor.

### Model training and evaluation

All four models use the same 20 selected predictors:

- Elastic Net and Ridge tune their regularization parameters with five-fold cross-validation on the training split.
- Random Forest uses 800 trees and a fixed random seed.
- XGBoost uses the validation split for early stopping.

The test split is used for the final model comparison.

## Results

The complete pipeline was executed twice with seed 42 and produced the same splits, selected features, and aggregate results.

| Model | Test log-RMSE | Test R² | RMSE (NTD/m²) | MAE (NTD/m²) | Test MAPE |
|---|---:|---:|---:|---:|---:|
| XGBoost | 0.205 | 0.758 | 23,343 | 13,866 | 13.6% |
| Random Forest | 0.215 | 0.733 | 23,703 | 13,663 | 14.0% |
| Elastic Net | 0.276 | 0.562 | 31,312 | 21,534 | 21.2% |
| Ridge | 0.276 | 0.562 | 31,313 | 21,535 | 21.2% |

Full-precision validation and test metrics are in [`results/model_scores.csv`](results/model_scores.csv). Random Forest and XGBoost feature-importance values are in [`results/feature_importance.csv`](results/feature_importance.csv). Log-RMSE and R² are calculated on the transformed target; RMSE, MAE, and MAPE are calculated after converting predictions back to NTD per square meter.

## Repository structure

```text
.
├── R/pipeline.R                  # Feature construction and preprocessing
├── data/README.md                # Local dataset placement
├── python/train_models.py        # Model training and evaluation
├── results/
│   ├── feature_importance.csv
│   └── model_scores.csv
├── scripts/prepare_data.R        # R command-line entry point
├── tests/
│   ├── test_pipeline.R
│   └── test_train_models.py
├── Makefile
└── requirements.txt
```

## Running the analysis

Requirements:

- R 4.4 or later with `dplyr`, `lubridate`, `randomForest`, `readr`, `RRF`, `stringr`, and `tibble`
- Python 3.10 or later
- A local copy of the transaction dataset

Create the Python virtual environment:

```bash
make setup
```

Place the data at `data/raw_UTF-8.csv`, then run:

```bash
make run
```

To use another path or seed:

```bash
make run DATA="/absolute/path/to/data.csv" SEED=42
```

Run the automated checks with:

```bash
make test
```

The checks cover floor and completion-year parsing, base feature construction, split reproducibility, training-derived numeric preprocessing, prediction metrics, and prepared-split validation. They do not constitute full end-to-end test coverage. The Python packages use bounded version ranges and the R packages are not locked, so dependency resolution may vary over time.

## Limitations

1. **Random holdout:** Transactions from similar areas or periods may appear in different splits. Temporal or grouped spatial validation is needed to measure future-period or new-area generalization.
2. **Data access:** Reproducing the reported values requires access to the same row-level dataset.
3. **Interpretation:** Feature importance indicates predictive association, not a causal effect on housing prices.

## Author

Pei-Ju Hsieh

## License

Copyright 2026 Pei-Ju Hsieh.

The code, documentation, and aggregate outputs included in this repository are licensed under the [Apache License 2.0](LICENSE). The row-level dataset is not part of this repository.
