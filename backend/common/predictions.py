import abc
import logging
import os

import numpy as np
import pandas as pd
import requests


logger = logging.getLogger(__name__)


def get_prediction_service(service_key):
    """
    Instantiates a prediction service by its key.

    Parameters
    ----------
    service_key : str
        The class name for the service.

    Returns
    -------
    An instance of PredictionService
    """
    if service_key == 'DataRobotV1APIPredictionService':
        return DataRobotV1APIPredictionService(
            server=os.environ['DATAROBOT_SERVER'],
            server_key=os.environ['DATAROBOT_SERVER_KEY'],
            deployment_id=os.environ['DATAROBOT_DEPLOYMENT_ID'],
            username=os.environ['DATAROBOT_USERNAME'],
            api_token=os.environ['DATAROBOT_API_TOKEN'],
        )
    return DummyPredictionService()


class PredictionService(object):
    """
    Abstract class for a service that can make chord predictions given audio features.
    """
    @abc.abstractmethod
    def predict(self, df):
        """
        Predict chord labels with confidence.

        Parameters
        ----------
        df : pandas.DataFrame
            Input data frame with audio features.

        Returns
        -------
        pandas.DataFrame
            Prediction data frame with two columns: 'name', 'confidence'.
        """
        pass


class PredictionError(Exception):
    """
    Occurs when chord predictions cannot be made.
    """
    pass


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


class DataRobotV1APIPredictionService(PredictionService):
    """
    A chord prediction service powered by DataRobot V1 API for model deployments.
    """
    def __init__(self, server, server_key, deployment_id, username, api_token):
        self.server = server
        self.server_key = server_key
        self.deployment_id = deployment_id
        self.username = username
        self.api_token = api_token

    def predict(self, df):
        logger.info(f'Using DataRobot V1 prediction service on data shape {df.shape}')
        rows = df.to_dict(orient='records')
        dr_payload = self.get_datarobot_predictions(rows)
        result = [
            self.get_label_and_confidence(row)
            for row in dr_payload['data']
        ]
        return pd.DataFrame(result, columns=['name', 'confidence'])

    def get_datarobot_predictions(self, rows):
        logger.info(f'Requesting DataRobot predictions for {len(rows)} rows')
        url = f'{self.server}/predApi/v1.0/deployments/{self.deployment_id}/predictions'
        response = requests.post(
            url=url,
            json=rows,
            auth=(self.username, self.api_token),
            headers={
                'Content-Type': 'application/json',
                'datarobot-key': self.server_key,
            }
        )
        logger.info(f'DataRobot response code: {response.status_code}')
        if response.status_code != 200:
            raise PredictionError(response.text)
        return response.json()

    def get_label_and_confidence(self, row):
        label = row['prediction']
        confidence = [
            val['value']
            for val in row['predictionValues']
            if val['label'] == label
        ][0]
        return [label, confidence]
