import pytest

import common.recognition as sut
from common.utilities import KnownRequestParseError


def test_recognize_file_nonexistent(nonexistent_audio_file, dummy_service):
    msg = 'Cannot load audio file. Error: .* No such file or directory'
    with pytest.raises(KnownRequestParseError, match=msg):
        sut.recognize_saved_file(nonexistent_audio_file, dummy_service)


def test_recognize_file_non_audio(saved_non_audio_file, dummy_service):
    msg = 'Cannot load audio file. Error: NoBackendError'
    with pytest.raises(KnownRequestParseError, match=msg):
        sut.recognize_saved_file(saved_non_audio_file, dummy_service)


def test_recognize_file(saved_audio_file, dummy_service):
    chords = sut.recognize_saved_file(saved_audio_file, dummy_service)
    assert len(chords) == 6
    for chord in chords:
        assert set(chord.keys()) == {'timeOffset', 'name', 'confidence'}
