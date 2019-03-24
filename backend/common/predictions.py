import abc

import numpy as np
import pandas as pd
import requests


class PredictionService(object):
    @abc.abstractmethod
    def predict(self, df):
        pass


class PredictionError(Exception):
    pass


class DummyPredictionService(PredictionService):
    def __init__(self, random_state=42):
        self.chord_names = [
            'C', 'D', 'E', 'F', 'G', 'A', 'B',
            'Cm', 'Dm', 'Em', 'Fm', 'Gm', 'Am', 'Bm',
        ]
        self.rng = np.random.RandomState(random_state)

    def predict(self, df):
        names = self.rng.choice(self.chord_names, size=len(df))
        confidences = self.rng.uniform(low=0.0, high=1.0, size=len(df))
        return pd.DataFrame({
            'name': names,
            'confidence': confidences,
        })


class DataRobotV1APIPredictionService(PredictionService):
    def __init__(self, server, server_key, deployment_id, username, api_token):
        self.server = server
        self.server_key = server_key
        self.deployment_id = deployment_id
        self.username = username
        self.api_token = api_token

    def predict(self, df):
        rows = df.to_dict(orient='records')
        dr_payload = self._get_datarobot_predictions(rows)
        result = [
            self._get_label_and_confidence(row)
            for row in dr_payload['data']
        ]
        return pd.DataFrame(result, columns=['name', 'confidence'])

    def _get_datarobot_predictions(self, rows):
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
        if response.status_code != 200:
            raise PredictionError(response.text)
        return response.json()

    def _get_label_and_confidence(self, row):
        label = row['prediction']
        confidence = [
            val['value']
            for val in row['predictionValues']
            if val['label'] == label
        ][0]
        return [label, confidence]
