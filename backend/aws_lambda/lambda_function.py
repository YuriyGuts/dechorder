import base64
import json
import os

from common.predictions import get_prediction_service
from common.recognition import recognize_saved_file
from common.utilities import KnownRequestParseError, extract_file_from_http_request


def serve_ok(result_obj):
    return {
        'statusCode': 200,
        'headers': {'Content-Type': 'application/json'},
        'body': json.dumps(result_obj),
    }


def serve_error(message, status_code=500):
    return {
        'statusCode': status_code,
        'headers': {'Content-Type': 'application/json'},
        'body': json.dumps({'message': message}),
    }


def lambda_handler(event, context):
    try:
        headers = event['headers']
        body = base64.b64decode(event['body'])
        request_id = event['requestContext']['requestId']
        upload_dir = '/tmp'
        uploaded_file = extract_file_from_http_request(headers, body, upload_dir, request_id)
        prediction_service = get_prediction_service(os.environ['DECHORDER_PREDICTION_SERVICE'])
        result = recognize_saved_file(uploaded_file.stored_filename, prediction_service)
        os.remove(uploaded_file.stored_filename)
        return serve_ok(result)

    except KnownRequestParseError as e:
        return serve_error(str(e), 400)

    except Exception as e:
        return serve_error(str(e), 500)
