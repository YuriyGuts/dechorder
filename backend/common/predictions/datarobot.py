import logging

import pandas as pd
import requests

from common.predictions import PredictionService, PredictionError


logger = logging.getLogger(__name__)


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
