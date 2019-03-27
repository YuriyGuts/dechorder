import json
import os
import uuid


ALLOWED_EXTENSIONS = ['.wav', '.mp3', '.m4a']


class KnownRequestParseError(Exception):
    """
    Occurs when encountering an HTTP request that does not conform to the API interface.
    """
    pass


class UploadedFile(object):
    """
    Represents a file extracted from a multipart/form-data HTTP request and saved to disk.
    """
    def __init__(self, original_filename, stored_filename, mime_type, metadata=None):
        self.original_filename = original_filename
        self.stored_filename = stored_filename
        self.mime_type = mime_type
        self.metadata = metadata or {}


def extract_file_from_http_request(headers, body, upload_dir, unique_id=None):
    """
    Parse the raw HTTP POST request and extract the audio file from it.

    Parameters
    ----------
    headers : dict
        Request headers.
    body : bytes
        Raw request body.
    upload_dir: str
        Path to the folder for storing extracted files.
    unique_id : str (optional)
        A string uniquely identifying this HTTP request.

    Returns
    -------
    UploadedFile
    """
    headers = {
        header.lower(): value
        for header, value in headers.items()
    }
    if 'content-type' not in headers or 'boundary=' not in headers['content-type']:
        msg = 'Expected a multipart/form-data request with content type defined'
        raise KnownRequestParseError(msg)

    unique_id = unique_id or str(uuid.uuid4())
    content_type = headers['content-type']

    # Separate the file part from multipart form data.
    newline = b'\r\n'
    boundary = content_type.split('boundary=')[-1].replace('"', '').encode('utf-8')
    initial_delimiter = b'--' + boundary + newline
    final_delimiter = newline + b'--' + boundary + b'--'
    try:
        file_part = body.split(initial_delimiter)[1].split(final_delimiter)[0]
    except Exception:
        raise KnownRequestParseError('Expected a non-empty multipart/form-data body')

    # Separate Content-Disposition, Content-Type (optional), and file content.
    file_part_lines = [line for line in file_part.split(newline) if line]
    cdisp_line = file_part_lines[0].decode('utf-8')
    ctype_line = file_part_lines[1]

    if ctype_line.startswith(b'Content-Type'):
        mime_type = ctype_line.decode('utf-8').replace('Content-Type: ', '')
        file_content = newline.join([line for line in file_part_lines[2:]])
    else:
        mime_type = 'text/plain'
        file_content = newline.join([line for line in file_part_lines[1:]])

    # Parse Content-Disposition to extract parameter name and original filename.
    cdisp_line = cdisp_line.replace('; name=', '"name": ')
    cdisp_line = cdisp_line.replace('; filename=', ', "filename": ')
    cdisp_line = '{' + cdisp_line.replace('Content-Disposition: form-data', '') + '}'
    try:
        content_disposition = json.loads(cdisp_line)
    except Exception:
        raise KnownRequestParseError('Malformed request body')

    # Check if the request form is valid.
    if content_disposition['name'] != 'audio-file':
        raise KnownRequestParseError('Expected a file with key "audio-file" in the request')

    original_filename = content_disposition['filename']
    original_extension = os.path.splitext(original_filename)[1].lower()
    if original_extension not in ALLOWED_EXTENSIONS:
        msg = 'Only the following file extensions are supported: ' + ', '.join(ALLOWED_EXTENSIONS)
        raise KnownRequestParseError(msg)

    # Save the file to disk.
    storage_path = os.path.join(upload_dir, f'{unique_id}{original_extension}')
    with open(storage_path, 'wb') as f:
        f.write(file_content)

    return UploadedFile(
        original_filename=original_filename,
        stored_filename=storage_path,
        mime_type=mime_type,
    )
