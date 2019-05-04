from unittest.mock import patch

import numpy as np
import pytest

import common.predictions as sut
from common.predictions.datarobot import DataRobotV1APIPredictionService
from common.predictions.dummy import DummyPredictionService
from common.predictions.embedded import EmbeddedPredictionService


def test_prediction_service_dummy(prediction_payload, dummy_service):
    preds = dummy_service.predict(prediction_payload)
    assert len(preds) == len(prediction_payload)
    expected_names = ['B', 'F', 'Am', 'Fm', 'Cm', 'Am', 'G', 'B']
    expected_confidences = [0.45, 0.10, 0.46, 0.33, 0.14, 0.65, 0.06, 0.72]
    assert np.array_equal(preds['name'], expected_names)
    assert np.allclose(preds['confidence'], expected_confidences, atol=1e-2)


def test_prediction_service_datarobot_v1(prediction_payload, datarobot_v1_service):
    labels = ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'Am']
    confidences = np.arange(0, len(labels)) * 0.1

    with patch.object(datarobot_v1_service, 'get_datarobot_predictions') as p:
        p.return_value = {
            'data': [
                {
                    'rowId': i,
                    'prediction': labels[i],
                    'predictionValues': [
                        {
                            'label': labels[j],
                            'value': confidences[j],
                        }
                        for j in range(len(labels))
                    ],
                }
                for i in range(len(prediction_payload))
            ]
        }
        preds = datarobot_v1_service.predict(prediction_payload)

    expected_names = labels
    expected_confidences = [0, 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7]
    assert np.array_equal(preds['name'], expected_names)
    assert np.allclose(preds['confidence'], expected_confidences, atol=1e-2)


def test_prediction_service_embedded(prediction_payload, embedded_service):
    preds = embedded_service.predict(prediction_payload)
    assert len(preds) == len(prediction_payload)
    expected_names = ['D', 'D', 'D', 'Bm', 'E', 'E', 'E', 'Fm']
    expected_confidences = [1.0, 1.0, 1.0, 0.74, 1.0, 1.0, 1.0, 1.0]
    assert np.array_equal(preds['name'], expected_names)
    assert np.allclose(preds['confidence'], expected_confidences, atol=1e-2)


@pytest.mark.parametrize('service_key, expected_type', [
    ('DataRobotV1APIPredictionService', DataRobotV1APIPredictionService),
    ('DummyPredictionService', DummyPredictionService),
    ('EmbeddedPredictionService', EmbeddedPredictionService),
])
def test_get_prediction_service(service_key, expected_type, monkeypatch):
    mock_env_vars = {
        'DATAROBOT_SERVER': '1',
        'DATAROBOT_SERVER_KEY': '2',
        'DATAROBOT_DEPLOYMENT_ID': '3',
        'DATAROBOT_USERNAME': '4',
        'DATAROBOT_API_TOKEN': '5',
    }
    for name, value in mock_env_vars.items():
        monkeypatch.setenv(name, value)

    svc = sut.get_prediction_service(service_key)
    assert isinstance(svc, expected_type)


def test_get_prediction_service_unknown_key():
    with pytest.raises(ValueError, match='Unknown prediction service: IDoNotExistService'):
        sut.get_prediction_service('IDoNotExistService')
