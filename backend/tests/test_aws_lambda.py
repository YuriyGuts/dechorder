import base64
import json
import os
from unittest.mock import Mock, patch

import pytest

import aws_lambda.lambda_function as sut
from common.utilities import KnownRequestParseError


@pytest.fixture
def request_context():
    return Mock()


@pytest.fixture
def configured_dummy_service(monkeypatch):
    monkeypatch.setitem(os.environ, 'DECHORDER_PREDICTION_SERVICE', 'DummyPredictionService')
    yield


@pytest.fixture
def valid_lambda_event(body_with_valid_audio_file, boundary):
    event = {
        'requestContext': {'requestId': 'cc220231-d310-4658-b90a-bb4ab57f6412'},
        'headers': {'content-type': 'multipart/form-data; boundary=' + boundary.decode('utf-8')},
        'body': base64.b64encode(body_with_valid_audio_file).decode('utf-8'),
    }
    return event


def test_lambda_valid_input(valid_lambda_event, request_context, configured_dummy_service):
    response = sut.lambda_handler(valid_lambda_event, request_context)
    assert response['statusCode'] == 200
    assert response['headers']['Content-Type'] == 'application/json'

    body = json.loads(response['body'])
    expected_time_offsets = [0.0, 1.0, 2.0, 4.0, 5.0, 6.0]
    assert len(body) == 6
    assert all([
        chord['name'] and chord['confidence'] and chord['timeOffset'] in expected_time_offsets
        for chord in body
    ])


def test_lambda_user_error(valid_lambda_event, request_context, configured_dummy_service):
    recognize_func = 'aws_lambda.lambda_function.recognize_saved_file'
    exception = KnownRequestParseError('Boo!')
    with patch(recognize_func, side_effect=exception):
        response = sut.lambda_handler(valid_lambda_event, request_context)

    assert response['statusCode'] == 400
    assert response['headers']['Content-Type'] == 'application/json'
    assert json.loads(response['body']) == {'message': 'Boo!'}


def test_lambda_server_error(valid_lambda_event, request_context, configured_dummy_service):
    recognize_func = 'aws_lambda.lambda_function.recognize_saved_file'
    exception = ValueError('I am an internal error')
    with patch(recognize_func, side_effect=exception):
        response = sut.lambda_handler(valid_lambda_event, request_context)

    assert response['statusCode'] == 500
    assert response['headers']['Content-Type'] == 'application/json'
    assert json.loads(response['body']) == {'message': 'I am an internal error'}
