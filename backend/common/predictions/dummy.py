import logging

import numpy as np
import pandas as pd

from common.predictions import PredictionService


logger = logging.getLogger(__name__)


class DummyPredictionService(PredictionService):
    """
    A chord prediction service that returns random chord predictions.
    """
    def __init__(self, random_state=42):
        self.chord_names = [
            'C', 'D', 'E', 'F', 'G', 'A', 'B',
            'Cm', 'Dm', 'Em', 'Fm', 'Gm', 'Am', 'Bm',
        ]
        self.rng = np.random.RandomState(random_state)

    def predict(self, df):
        logger.info(f'Using dummy prediction service on data shape {df.shape}')
        names = self.rng.choice(self.chord_names, size=len(df))
        confidences = self.rng.uniform(low=0.0, high=1.0, size=len(df))
        return pd.DataFrame({
            'name': names,
            'confidence': confidences,
        })
