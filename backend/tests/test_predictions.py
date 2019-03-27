from unittest.mock import patch

import numpy as np

import common.predictions as sut


def test_get_prediction_service_dummy(prediction_payload, dummy_service):
    preds = dummy_service.predict(prediction_payload)
    assert len(preds) == len(prediction_payload)
    expected_names = ['B', 'F', 'Am', 'Fm', 'Cm', 'Am', 'G', 'B']
    expected_confidences = [0.45, 0.10, 0.46, 0.33, 0.14, 0.65, 0.06, 0.72]
    assert np.array_equal(preds['name'], expected_names)
    assert np.allclose(preds['confidence'], expected_confidences, atol=1e-2)


def test_get_prediction_service_datarobot_v1(prediction_payload, datarobot_v1_service):
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


def test_get_prediction_service_keyed():
    svc = sut.get_prediction_service('DummyPredictionService')
    assert isinstance(svc, sut.DummyPredictionService)
