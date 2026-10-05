PYTHON ?= .venv/bin/python
DATA ?= data/raw_UTF-8.csv
SEED ?= 42

.PHONY: setup prepare train run test clean

setup:
	python3 -m venv .venv
	.venv/bin/python -m pip install --upgrade pip
	.venv/bin/python -m pip install -r requirements.txt

prepare:
	Rscript scripts/prepare_data.R --input "$(DATA)" --output data/processed --seed "$(SEED)"

train:
	$(PYTHON) python/train_models.py --input-dir data/processed --output-dir results --seed "$(SEED)"

run: prepare train

test:
	Rscript tests/test_pipeline.R
	$(PYTHON) -m unittest discover -s tests -p 'test_*.py'

clean:
	rm -rf data/processed models logs tmp
	rm -f results/predictions*.csv
