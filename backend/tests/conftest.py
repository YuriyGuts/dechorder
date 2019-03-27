import os

import pytest

from common.features import featurize_file
from common.predictions import DummyPredictionService, DataRobotV1APIPredictionService


@pytest.fixture
def saved_audio_file():
    return os.path.join('tests', 'testdata', 'd-e-jazz.mp3')


@pytest.fixture()
def saved_non_audio_file():
    return os.path.join('tests', 'conftest.py')


@pytest.fixture()
def nonexistent_audio_file():
    return os.path.join('tests', 'testdata', 'i-do-not-exist.mp3')


@pytest.fixture
def dummy_service():
    return DummyPredictionService(random_state=42)


@pytest.fixture
def datarobot_v1_service():
    return DataRobotV1APIPredictionService(
        server='datarobot-server',
        server_key='datarobot-server-key',
        deployment_id='datarobot-deployment-id',
        username='datarobot-username',
        api_token='datarobot-api-token',
    )


@pytest.fixture
def prediction_payload(saved_audio_file):
    df = featurize_file(saved_audio_file)
    df = df.drop(columns=['time_offset', 'is_silent'])
    return df
