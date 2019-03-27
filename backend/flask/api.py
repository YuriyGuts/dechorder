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

from common.predictions import get_prediction_service
from common.recognition import recognize_saved_file
from common.utilities import ALLOWED_EXTENSIONS, KnownRequestParseError, UploadedFile


app = Flask(__name__)
app.config['UPLOAD_FOLDER'] = os.environ['FLASK_UPLOAD_FOLDER']
app.config['PREDICTION_SERVICE'] = os.environ['DECHORDER_PREDICTION_SERVICE']


prediction_service = None


def bootstrap():
    formatter = RequestFormatter(
        '[%(asctime)s] %(remote_addr)s requested %(url)s\n'
        '%(levelname)s in %(module)s: %(message)s'
    )
    default_handler.setFormatter(formatter)

    global prediction_service
    prediction_service = get_prediction_service(app.config['PREDICTION_SERVICE'])


class RequestFormatter(logging.Formatter):
    def format(self, record):
        record.url = request.url
        record.remote_addr = request.remote_addr
        return super().format(record)


def extract_uploaded_file():
    if 'audio-file' not in request.files:
        raise KnownRequestParseError('Expected a file with key "audio-file" in the request')

    audio_file = request.files['audio-file']
    if not audio_file:
        raise KnownRequestParseError('Audio file missing')

    name, ext = os.path.splitext(audio_file.filename)
    if ext.lower() not in ALLOWED_EXTENSIONS:
        msg = 'Only the following file extensions are supported: ' + ', '.join(ALLOWED_EXTENSIONS)
        raise KnownRequestParseError(msg)

    filename = datetime.datetime.now().strftime('%Y%m%d-%H%M%S') + ext
    saved_audio_path = os.path.join(app.config['UPLOAD_FOLDER'], filename)
    audio_file.save(saved_audio_path)

    return UploadedFile(
        original_filename=audio_file.filename,
        stored_filename=saved_audio_path,
        mime_type=audio_file.content_type,
    )


def serve_error(message, status_code=500):
    return jsonify({'message': message}), status_code


def serve_ok(result_obj):
    return jsonify(result_obj)


@app.route('/recognize', methods=['POST'])
def recognize_file():
    try:
        uploaded_file = extract_uploaded_file()
        response_payload = recognize_saved_file(uploaded_file.stored_filename, prediction_service)
        return serve_ok(response_payload)

    except KnownRequestParseError as e:
        return serve_error(str(e), 400)

    except Exception as e:
        return serve_error(str(e), 500)


def main():
    test_filename = 'upload/test-audio.wav' if len(sys.argv) <= 1 else sys.argv[1]
    print(f'Running in test mode: recognizing {test_filename}')
    print(recognize_saved_file(test_filename, prediction_service))


bootstrap()
if __name__ == '__main__':
    main()
