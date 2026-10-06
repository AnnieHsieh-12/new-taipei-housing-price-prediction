import sys
import tempfile
import unittest
from pathlib import Path

import numpy as np
import pandas as pd

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "python"))
from train_models import evaluate_predictions, load_splits  # noqa: E402


class EvaluatePredictionsTest(unittest.TestCase):
    def test_perfect_predictions_have_zero_error(self) -> None:
        raw = np.array([100.0, 200.0, 300.0])
        logged = np.log1p(raw)
        metrics = evaluate_predictions(logged, logged, raw)
        self.assertAlmostEqual(metrics["rmse_log"], 0.0)
        self.assertAlmostEqual(metrics["mae_raw"], 0.0)
        self.assertAlmostEqual(metrics["r2_log"], 1.0)


class LoadSplitsTest(unittest.TestCase):
    def write_splits(self, directory: Path, frames: dict[str, pd.DataFrame]) -> None:
        for name, frame in frames.items():
            frame.to_csv(directory / f"{name}.csv", index=False)

    def valid_frames(self) -> dict[str, pd.DataFrame]:
        frame = pd.DataFrame(
            {"feature": [1.0, 2.0], "target_log": [0.1, 0.2], "target_raw": [10.0, 20.0]}
        )
        return {name: frame.copy() for name in ("train", "valid", "test")}

    def test_rejects_mismatched_columns(self) -> None:
        with tempfile.TemporaryDirectory() as temporary_directory:
            directory = Path(temporary_directory)
            frames = self.valid_frames()
            frames["valid"] = frames["valid"].drop(columns="feature")
            self.write_splits(directory, frames)
            with self.assertRaisesRegex(ValueError, "columns do not match"):
                load_splits(directory)

    def test_rejects_missing_values(self) -> None:
        with tempfile.TemporaryDirectory() as temporary_directory:
            directory = Path(temporary_directory)
            frames = self.valid_frames()
            frames["test"].loc[0, "feature"] = np.nan
            self.write_splits(directory, frames)
            with self.assertRaisesRegex(ValueError, "contains missing values"):
                load_splits(directory)


if __name__ == "__main__":
    unittest.main()
