import tempfile
import os

import pytest

import common.utilities as sut


@pytest.fixture
def upload_dir():
    return tempfile.gettempdir()


@pytest.fixture
def valid_headers(boundary):
    return {'Content-Type': 'multipart/form-data; boundary=' + boundary.decode('utf-8')}


def test_extract_file(valid_headers, body_with_valid_audio_file, upload_dir):
    request_id = 'some-request-id'
    file = sut.extract_file_from_http_request(
        valid_headers,
        body_with_valid_audio_file,
        upload_dir,
        request_id,
    )
    assert file.original_filename == 'd-e-jazz.mp3'
    assert file.stored_filename == os.path.join(upload_dir, request_id + '.mp3')
    assert file.mime_type == 'audio/mp3'


def test_extract_file_missing_headers(body_with_valid_audio_file, upload_dir):
    headers = {'Accept': 'application/json'}
    msg = 'Expected a multipart/form-data request with content type defined'
    with pytest.raises(sut.KnownRequestParseError, match=msg):
        sut.extract_file_from_http_request(headers, body_with_valid_audio_file, upload_dir)


def test_extract_file_empty_body(valid_headers, upload_dir):
    body = bytearray([])
    msg = 'Expected a non-empty multipart/form-data body'
    with pytest.raises(sut.KnownRequestParseError, match=msg):
        sut.extract_file_from_http_request(valid_headers, body, upload_dir)


def test_extract_file_invalid_param_name(valid_headers, body_with_valid_audio_file, upload_dir):
    body = body_with_valid_audio_file.replace(b'audio-file', b'file')
    msg = 'Expected a file with key "audio-file" in the request'
    with pytest.raises(sut.KnownRequestParseError, match=msg):
        sut.extract_file_from_http_request(valid_headers, body, upload_dir)


def test_extract_file_invalid_extension(valid_headers, body_with_valid_audio_file, upload_dir):
    body = body_with_valid_audio_file.replace(b'd-e-jazz.mp3', b'd-e-jazz.aiff')
    msg = r'Only the following file extensions are supported: \.wav, \.mp3, \.m4a'
    with pytest.raises(sut.KnownRequestParseError, match=msg):
        sut.extract_file_from_http_request(valid_headers, body, upload_dir)
