import sys
import unittest
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "python"))
from train_models import evaluate_predictions  # noqa: E402


class EvaluatePredictionsTest(unittest.TestCase):
    def test_perfect_predictions_have_zero_error(self) -> None:
        raw = np.array([100.0, 200.0, 300.0])
        logged = np.log1p(raw)
        metrics = evaluate_predictions(logged, logged, raw)
        self.assertAlmostEqual(metrics["rmse_log"], 0.0)
        self.assertAlmostEqual(metrics["mae_raw"], 0.0)
        self.assertAlmostEqual(metrics["r2_log"], 1.0)


if __name__ == "__main__":
    unittest.main()
