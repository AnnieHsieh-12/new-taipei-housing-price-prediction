# New Taipei City Housing Price Prediction

An independent, reproducible machine-learning project for estimating real-estate unit prices in New Taipei City. The repository provides a leakage-aware workflow that combines R-based data preparation with Python-based model training and evaluation.

## Overview

The project studies whether property characteristics, transaction attributes, geographic variables, transportation proximity, and area-level demographic indicators can explain variation in transaction unit prices.

- **Target:** `log1p(單價元平方公尺)` — the natural logarithm of unit price in New Taiwan dollars per square meter after adding one.
- **Original data:** 14,092 transaction records and 199 variables.
- **Analysis sample:** 14,087 records with a valid positive target value.
- **Split:** 70% training, 15% validation, and 15% test data.
- **Models:** Elastic Net, Ridge, Random Forest, and XGBoost.
- **Feature selection:** Regularized Random Forest, fitted on training data only.
- **Reproducibility:** Configurable random seed, automated commands, and tests for core parsing and evaluation functions.

## Data availability and disclosure

The transaction-level dataset is intentionally excluded from this repository. It contains address-level locations, exact coordinates, transaction identifiers, and other row-level fields that cannot be redistributed through this project.

The repository includes only source code, documentation, and aggregate model outputs. Raw data, processed row-level data, and model-ready splits are protected by `.gitignore`.

Users with authorized access to the dataset may place it at `data/raw_UTF-8.csv` or provide another local path when running the pipeline. The Apache License 2.0 for this repository does **not** grant any rights to the excluded dataset.

## Methodology

### 1. Deterministic feature construction

The R preparation module converts the original mixed-format records into numeric predictors. Its transformations include:

- parsing Chinese floor descriptions and underground levels;
- extracting land, building, and parking counts from transaction strings;
- deriving transaction year, month, building completion year, and building age;
- encoding selected binary housing attributes; and
- retaining available property, geographic, proximity, and demographic variables.

### 2. Leakage-aware data preparation

Records are divided into training, validation, and test sets before any data-dependent transformation is fitted. The following operations learn their parameters exclusively from the training set:

- median imputation;
- interquartile-range outlier limits;
- principal component analysis for grouped demographic variables; and
- Regularized Random Forest feature selection.

The fitted transformations are then applied unchanged to the validation and test sets. Target values are never imputed, capped, or included as predictors.

### 3. Model training and evaluation

The modeling module trains four regressors on the same 20 selected predictors:

- **Elastic Net:** cross-validated regularization and mixing parameters;
- **Ridge:** cross-validated L2 regularization;
- **Random Forest:** 800 trees with a fixed random seed; and
- **XGBoost:** validation-based early stopping with fixed tree and sampling parameters.

Validation data are used for XGBoost early stopping. Test data are reserved for the final model comparison.

## Verified results

The complete pipeline was executed twice with seed 42 and reproduced the same splits, selected features, and aggregate results.

| Model | Test log-RMSE | Test R² | RMSE (NTD/m²) | MAE (NTD/m²) | Test MAPE |
|---|---:|---:|---:|---:|---:|
| XGBoost | 0.205 | 0.758 | 23,343 | 13,866 | 13.6% |
| Random Forest | 0.215 | 0.733 | 23,703 | 13,663 | 14.0% |
| Elastic Net | 0.276 | 0.562 | 31,312 | 21,534 | 21.2% |
| Ridge | 0.276 | 0.562 | 31,313 | 21,535 | 21.2% |

Full-precision validation and test results are available in [`results/model_scores.csv`](results/model_scores.csv). Aggregate Random Forest and XGBoost importance values are available in [`results/feature_importance.csv`](results/feature_importance.csv).

### Metric interpretation

- **Log-RMSE:** root mean squared error evaluated on `log1p` unit price; lower is better.
- **R²:** proportion of variance explained on the transformed target scale; higher is better.
- **RMSE and MAE:** prediction error after converting estimates back to New Taiwan dollars per square meter.
- **MAPE:** mean absolute percentage error on the original unit-price scale.

These results measure interpolation performance under one reproducible random split. They do not establish future-year, out-of-region, causal, or production performance.

## Repository structure

```text
.
├── R/
│   └── pipeline.R              # Feature construction and training-only preprocessing
├── data/
│   └── README.md               # Private-data placement and disclosure guidance
├── python/
│   └── train_models.py         # Model training and aggregate evaluation
├── results/
│   ├── feature_importance.csv  # Aggregate feature-importance output
│   └── model_scores.csv        # Full-precision validation and test metrics
├── scripts/
│   └── prepare_data.R          # Command-line adapter for the R pipeline
├── tests/
│   ├── test_pipeline.R         # Parsing and split checks
│   └── test_train_models.py    # Metric-function checks
├── LICENSE                     # Apache License 2.0
├── Makefile                    # Reproducible setup, run, test, and clean commands
└── requirements.txt            # Python dependencies
```

## Reproducing the analysis

### Prerequisites

- R 4.4 or later
- Python 3.10 or later
- An authorized local copy of the UTF-8 transaction dataset

Install the required R packages once:

```r
install.packages(c(
  "dplyr",
  "lubridate",
  "randomForest",
  "readr",
  "RRF",
  "stringr",
  "tibble"
))
```

Create the isolated Python environment:

```bash
make setup
```

Place the authorized dataset at `data/raw_UTF-8.csv`, then run the complete workflow:

```bash
make run
```

To use a dataset stored elsewhere or change the seed:

```bash
make run DATA="/absolute/path/to/private-data.csv" SEED=42
```

Run the checks independently:

```bash
make test
```

### Generated outputs

The preparation stage writes ignored row-level artifacts to `data/processed/`, including fixed train, validation, and test splits. The modeling stage writes aggregate metrics and feature importance to `results/`.

## Reproducibility safeguards

- No user-specific absolute paths are stored in the source code.
- Raw and processed row-level data are excluded from Git.
- A single command runs the complete R-to-Python workflow.
- The seed is configurable and recorded with the split summary.
- Preprocessing and feature selection are fitted on training data only.
- The same prepared splits are shared by all models.
- Core parsing and metric functions have automated checks.

## Limitations

1. **Random holdout:** Transactions from similar areas or periods may appear in multiple splits. A temporal or grouped spatial holdout is needed to assess stronger forms of generalization.
2. **Private data dependency:** Other users cannot reproduce the numerical results without authorized access to the same dataset.
3. **Observational analysis:** Feature importance describes predictive association, not causal effects on housing prices.
4. **Scope:** The results apply only to the observed New Taipei City records and evaluated target definition.
5. **Deployment:** The project does not include a serving interface, monitoring system, or external validation and should not be described as production-ready.

## Author

**Pei-Ju Hsieh**

Independent project covering data preparation, feature engineering, leakage-aware evaluation, model comparison, testing, and repository implementation.

## License

Copyright 2026 Pei-Ju Hsieh.

The source code, documentation, and included aggregate outputs in this repository are licensed under the [Apache License 2.0](LICENSE). The excluded transaction-level dataset is not covered by this license and may not be redistributed through this project.
