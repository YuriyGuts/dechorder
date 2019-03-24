#!/usr/bin/env python3
"""
Flask API serving the chord recognition routes.

* To run as a web server, run start.sh from this directory.
* To run in test mode and recognize a single file, run it as a Python script:
  PYTHONPATH=.. ./api.py <filename>
"""
import datetime
import logging
import os
import sys

from flask import Flask, request, jsonify
from flask.logging import default_handler

from common.predictions import DummyPredictionService, DataRobotV1APIPredictionService
from common.recognition import recognize_saved_file


app = Flask(__name__)

# Folder for saving uploaded audio files.
app.config['UPLOAD_FOLDER'] = 'upload'

# Service for predicting chords.
# - dummy: random predictions
# - datarobot-v1: DataRobot V1 API predictions (environment variables required)
app.config['PREDICTION_SERVICE'] = 'dummy'

ALLOWED_EXTENSIONS = ['.wav', '.mp3', '.m4a']
prediction_service = None


def bootstrap():
    formatter = RequestFormatter(
        '[%(asctime)s] %(remote_addr)s requested %(url)s\n'
        '%(levelname)s in %(module)s: %(message)s'
    )
    default_handler.setFormatter(formatter)

    global prediction_service
    prediction_service = get_prediction_service()


class RequestFormatter(logging.Formatter):
    def format(self, record):
        record.url = request.url
        record.remote_addr = request.remote_addr
        return super().format(record)


def get_prediction_service():
    if app.config['PREDICTION_SERVICE'] == 'datarobot-v1':
        return DataRobotV1APIPredictionService(
            server=os.environ['DATAROBOT_SERVER'],
            server_key=os.environ['DATAROBOT_SERVER_KEY'],
            deployment_id=os.environ['DATAROBOT_DEPLOYMENT_ID'],
            username=os.environ['DATAROBOT_USERNAME'],
            api_token=os.environ['DATAROBOT_API_TOKEN'],
        )
    return DummyPredictionService()


@app.route('/recognize', methods=['POST'])
def recognize_file():
    if 'audio-file' not in request.files:
        return 'Expected "audio-file" parameter in request', 400

    audio_file = request.files['audio-file']
    if not audio_file:
        return 'Audio data missing', 400

    name, ext = os.path.splitext(audio_file.filename)
    if ext.lower() not in ALLOWED_EXTENSIONS:
        return f'Unsupported audio file format: {ext}', 400

    filename = datetime.datetime.now().strftime('%Y%m%d-%H%M%S') + ext
    saved_audio_path = os.path.join(app.config['UPLOAD_FOLDER'], filename)
    audio_file.save(saved_audio_path)

    response_payload = recognize_saved_file(saved_audio_path, prediction_service)
    return jsonify(response_payload)


def main():
    test_filename = 'upload/test-audio.wav' if len(sys.argv) <= 1 else sys.argv[1]
    print(f'Running in test mode: recognizing {test_filename}')
    print(recognize_saved_file(test_filename, prediction_service))


bootstrap()
if __name__ == '__main__':
    main()
