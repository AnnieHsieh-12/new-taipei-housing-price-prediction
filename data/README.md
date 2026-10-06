# Local dataset placement

The transaction-level dataset used by this project is not included in this repository. It contains address-level property locations, exact coordinates, transaction identifiers, and other row-level information.

To run the project locally, place the private UTF-8 CSV at:

```text
data/raw_UTF-8.csv
```

The preparation module expects the target column `單價元平方公尺`. It uses only fields that are present, so optional predictors may be absent without stopping the pipeline. The original local analysis used 14,092 rows and 199 columns.

All files under `data/`, except this documentation file, are ignored by Git.

The repository's Apache License 2.0 applies to the code, documentation, and aggregate outputs included in the repository. The row-level dataset is not included.
