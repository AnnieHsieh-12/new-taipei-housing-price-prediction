"""Train housing-price models from fixed, preprocessed data splits."""

from __future__ import annotations

import argparse
from pathlib import Path

import numpy as np
import pandas as pd
import xgboost as xgb
from sklearn.ensemble import RandomForestRegressor
from sklearn.linear_model import ElasticNetCV, RidgeCV
from sklearn.metrics import mean_absolute_error, mean_squared_error, r2_score
from sklearn.pipeline import make_pipeline
from sklearn.preprocessing import StandardScaler

TARGET_LOG = "target_log"
TARGET_RAW = "target_raw"


def evaluate_predictions(
    y_true_log: np.ndarray,
    y_pred_log: np.ndarray,
    y_true_raw: np.ndarray,
) -> dict[str, float]:
    """Return log-space and original-scale regression metrics."""
    y_pred_raw = np.expm1(y_pred_log)
    return {
        "rmse_log": float(np.sqrt(mean_squared_error(y_true_log, y_pred_log))),
        "mae_log": float(mean_absolute_error(y_true_log, y_pred_log)),
        "r2_log": float(r2_score(y_true_log, y_pred_log)),
        "rmse_raw": float(np.sqrt(mean_squared_error(y_true_raw, y_pred_raw))),
        "mae_raw": float(mean_absolute_error(y_true_raw, y_pred_raw)),
        "mape_raw": float(np.mean(np.abs((y_true_raw - y_pred_raw) / y_true_raw)) * 100),
    }


def load_splits(input_dir: Path) -> dict[str, pd.DataFrame]:
    splits = {
        name: pd.read_csv(input_dir / f"{name}.csv")
        for name in ("train", "valid", "test")
    }
    expected_columns = set(splits["train"].columns)
    if not {TARGET_LOG, TARGET_RAW}.issubset(expected_columns):
        raise ValueError(f"Prepared data must include {TARGET_LOG!r} and {TARGET_RAW!r}.")
    for name, frame in splits.items():
        if set(frame.columns) != expected_columns:
            raise ValueError(f"{name}.csv columns do not match train.csv.")
        if frame.isna().any().any():
            raise ValueError(f"{name}.csv contains missing values.")
    return splits


def train_models(input_dir: Path, output_dir: Path, seed: int = 42) -> pd.DataFrame:
    """Train four models and write aggregate metrics and feature importance."""
    output_dir.mkdir(parents=True, exist_ok=True)
    splits = load_splits(input_dir)
    features = [
        column
        for column in splits["train"].columns
        if column not in (TARGET_LOG, TARGET_RAW)
    ]

    arrays: dict[str, tuple[np.ndarray, np.ndarray, np.ndarray]] = {}
    for name, frame in splits.items():
        arrays[name] = (
            frame[features].to_numpy(dtype=float),
            frame[TARGET_LOG].to_numpy(dtype=float),
            frame[TARGET_RAW].to_numpy(dtype=float),
        )

    x_train, y_train, _ = arrays["train"]
    x_valid, y_valid, valid_raw = arrays["valid"]
    x_test, y_test, test_raw = arrays["test"]

    elastic_net = make_pipeline(
        StandardScaler(),
        ElasticNetCV(
            l1_ratio=[0.1, 0.5, 0.9, 1.0],
            alphas=np.logspace(-4, 1, 50),
            cv=5,
            random_state=seed,
            max_iter=100_000,
            n_jobs=-1,
        ),
    )
    ridge = make_pipeline(
        StandardScaler(),
        RidgeCV(alphas=np.logspace(-4, 4, 60), cv=5),
    )
    random_forest = RandomForestRegressor(
        n_estimators=800,
        max_features="sqrt",
        min_samples_leaf=2,
        random_state=seed,
        n_jobs=-1,
    )

    elastic_net.fit(x_train, y_train)
    ridge.fit(x_train, y_train)
    random_forest.fit(x_train, y_train)

    dtrain = xgb.DMatrix(x_train, label=y_train, feature_names=features)
    dvalid = xgb.DMatrix(x_valid, label=y_valid, feature_names=features)
    dtest = xgb.DMatrix(x_test, label=y_test, feature_names=features)
    booster = xgb.train(
        params={
            "objective": "reg:squarederror",
            "eval_metric": "rmse",
            "max_depth": 6,
            "eta": 0.05,
            "subsample": 0.8,
            "colsample_bytree": 0.8,
            "min_child_weight": 5,
            "seed": seed,
        },
        dtrain=dtrain,
        num_boost_round=3000,
        evals=[(dtrain, "train"), (dvalid, "valid")],
        early_stopping_rounds=100,
        verbose_eval=False,
    )

    predictions = {
        "Elastic Net": {
            "valid": elastic_net.predict(x_valid),
            "test": elastic_net.predict(x_test),
        },
        "Ridge": {
            "valid": ridge.predict(x_valid),
            "test": ridge.predict(x_test),
        },
        "Random Forest": {
            "valid": random_forest.predict(x_valid),
            "test": random_forest.predict(x_test),
        },
        "XGBoost": {
            "valid": booster.predict(dvalid, iteration_range=(0, booster.best_iteration + 1)),
            "test": booster.predict(dtest, iteration_range=(0, booster.best_iteration + 1)),
        },
    }

    metric_rows: list[dict[str, float | str]] = []
    for model_name, model_predictions in predictions.items():
        metric_rows.append(
            {
                "model": model_name,
                "split": "valid",
                **evaluate_predictions(y_valid, model_predictions["valid"], valid_raw),
            }
        )
        metric_rows.append(
            {
                "model": model_name,
                "split": "test",
                **evaluate_predictions(y_test, model_predictions["test"], test_raw),
            }
        )

    scores = pd.DataFrame(metric_rows).sort_values(["split", "rmse_log"])
    scores.to_csv(output_dir / "model_scores.csv", index=False)

    importance_rows: list[dict[str, float | str]] = []
    for feature, value in zip(features, random_forest.feature_importances_, strict=True):
        importance_rows.append(
            {"model": "Random Forest", "feature": feature, "importance": float(value)}
        )
    for feature, value in booster.get_score(importance_type="gain").items():
        importance_rows.append(
            {"model": "XGBoost", "feature": feature, "importance": float(value)}
        )

    pd.DataFrame(importance_rows).sort_values(
        ["model", "importance"], ascending=[True, False]
    ).to_csv(output_dir / "feature_importance.csv", index=False)

    return scores


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input-dir", type=Path, default=Path("data/processed"))
    parser.add_argument("--output-dir", type=Path, default=Path("results"))
    parser.add_argument("--seed", type=int, default=42)
    return parser.parse_args()


if __name__ == "__main__":
    arguments = parse_args()
    result = train_models(arguments.input_dir, arguments.output_dir, arguments.seed)
    print(result.to_string(index=False))
