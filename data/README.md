# Private dataset placement

The transaction-level dataset used by this project is not distributed in this repository. It contains exact property locations and other row-level fields that should not be republished.

To run the project locally, place the private UTF-8 CSV at:

```text
data/raw_UTF-8.csv
```

The preparation module expects the target column `單價元平方公尺`. It uses only fields that are present, so optional predictors may be absent without stopping the pipeline. The original local analysis used 14,092 rows and 199 columns.

All files under `data/`, except this documentation file, are ignored by Git.
