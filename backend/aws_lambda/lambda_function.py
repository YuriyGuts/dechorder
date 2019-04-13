import base64
import json
import logging
import os

from common.predictions import get_prediction_service
from common.recognition import recognize_saved_file
from common.utilities import KnownRequestParseError, extract_file_from_http_request


logger = None


def setup_logging():
    global logger
    logger = logging.getLogger()
    del logger.handlers[:]
    log_format = '{asctime} | {levelname:<8s} | {message} [{filename}:{lineno}]'
    logging.basicConfig(level=logging.INFO, format=log_format, style='{')
    logger = logging.getLogger()


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
        setup_logging()
        logger.info('Lambda handler started')

        headers = event['headers']
        body = base64.b64decode(event['body'])
        request_id = event['requestContext']['requestId']
        upload_dir = '/tmp'
        logger.info(f'Request ID: {request_id}. Body length: {len(body)} bytes')

        uploaded_file = extract_file_from_http_request(headers, body, upload_dir, request_id)
        prediction_service = get_prediction_service(os.environ['DECHORDER_PREDICTION_SERVICE'])
        result = recognize_saved_file(uploaded_file.stored_filename, prediction_service)
        os.remove(uploaded_file.stored_filename)

        logger.info(f'Recognition successful, returning {len(result)} records')
        return serve_ok(result)

    except KnownRequestParseError as e:
        logger.info(f'Recognition failed, returning user error: {str(e)}')
        return serve_error(str(e), 400)

    except Exception as e:
        logger.info(f'Recognition failed, returning internal error: {str(e)}')
        return serve_error(str(e), 500)
