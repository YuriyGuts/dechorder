"""
Standalone usage: embedded.py [-h] --mode MODE --data-path DATAPATH [--model-path MODELPATH]

Train the embedded model for classifying chords

optional arguments:
  --mode MODE              mode (currently, only "train" is available)
  --data-path DATAPATH     path to the training dataset in CSV format
  --model-path MODELPATH   (optional) file path for saving the trained model

Note: you might need to set PYTHONPATH when running this. Example:

PYTHONPATH=/project-root/backend \
    python embedded.py --mode train --data-path /project-root/data/featurized/major-minor.csv
"""

import argparse
import logging
import os
import pickle
import pprint
import sys

import numpy as np
import pandas as pd
from sklearn.model_selection import KFold, cross_validate
from sklearn.neural_network import MLPClassifier

from common.predictions import PredictionService, PredictionError


logger = logging.getLogger(__name__)
DEFAULT_MODEL_FILENAME = 'embedded_model.pkl'


class EmbeddedPredictionService(PredictionService):
    """
    A chord prediction service powered by a neural network classifier embedded in the backend
    application. Requires the model to be saved as `DEFAULT_MODEL_FILENAME` in the local directory.
    """
    def __init__(self):
        super().__init__()
        self.model = None

    def load_model_if_needed(self):
        if self.model:
            # Already loaded.
            return

        # Unpickle the model from disk and keep it in memory.
        current_dir_path = os.path.dirname(os.path.realpath(__file__))
        pickle_filename = os.path.join(current_dir_path, DEFAULT_MODEL_FILENAME)
        if not os.path.exists(pickle_filename):
            msg = f'Model file ({pickle_filename}) does not exist. '
            msg += 'Please train it first by running "python embedded.py --mode train".'
            raise PredictionError(msg)

        with open(pickle_filename, 'rb') as fp:
            self.model = pickle.load(fp)

    def predict(self, df):
        logger.info(f'Using embedded prediction service on data shape {df.shape}')
        self.load_model_if_needed()
        names = self.model.predict(df)
        confidences = np.max(self.model.predict_proba(df), axis=1)
        return pd.DataFrame({
            'name': names,
            'confidence': confidences,
        })


def parse_command_line_args(args):
    program_desc = 'Train the embedded model for classifying chords'
    parser = argparse.ArgumentParser(description=program_desc)
    parser.add_argument(
        '--mode',
        required=True,
        metavar='MODE',
        help='mode (currently, only "train" is available)',
    )
    parser.add_argument(
        '--data-path',
        metavar='DATAPATH',
        required=True,
        help='path to the training dataset in CSV format',
    )
    parser.add_argument(
        '--model-path',
        metavar='MODELPATH',
        required=False,
        help='(optional) file path for saving the trained model',
    )
    return parser.parse_args(args)


def train(data_path, model_path=None):
    """
    Train a built-in neural network classifier using the specified training dataset
    and save it to disk.

    We're using scikit-learn instead of TensorFlow, PyTorch or Keras here to minimize the size of
    AWS Lambda deployment package. Scikit-learn is already used in librosa so this creates no
    additional overhead other than the pickle file.

    Parameters
    ----------
    data_path : str
        Path to the CSV training dataset.
    model_path : str
        (Optional) Path for saving the trained model. If omitted, will use the default path.
    """
    logger.info(f'Reading the training data from "{data_path}"...')
    df = pd.read_csv(data_path)

    X = df.drop(columns='chord')
    y = df['chord']

    logger.info('Training the neural network...')
    model = MLPClassifier(
        hidden_layer_sizes=(13, 19),
        activation='relu',
        alpha=0.001,
        solver='lbfgs',
        shuffle=True,
        batch_size='auto',
        learning_rate_init=0.001,
        nesterovs_momentum=True,
        momentum=0.9,
        random_state=42,
        verbose=False,
    )
    model.fit(X, y)

    current_dir_path = os.path.dirname(os.path.realpath(__file__))
    pickle_filename = model_path or os.path.join(current_dir_path, DEFAULT_MODEL_FILENAME)
    logger.info(f'Saving the model to {pickle_filename}...')
    with open(pickle_filename, 'wb') as fp:
        pickle.dump(model, fp)

    logger.info('Starting cross-validation...')
    cv = KFold(n_splits=5, shuffle=True, random_state=42)
    scores_to_compute = ['neg_log_loss', 'accuracy', 'f1_weighted']
    cross_val_report = cross_validate(model, X, y, scoring=scores_to_compute, cv=cv)

    print('Cross-validation report:')
    pprint.pprint(cross_val_report)

    logger.info('Done')


def main():
    log_format = '{asctime} | {levelname:<8s} | {message} [{filename}:{lineno}]'
    logging.basicConfig(level=logging.INFO, format=log_format, style='{')

    logger.info('Running as a standalone script')
    args = parse_command_line_args(sys.argv[1:])
    if args.mode == 'train':
        train(args.data_path, args.model_path)


if __name__ == '__main__':
    main()
