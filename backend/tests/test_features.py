import numpy as np
import pytest

import common.features as sut
from common.utilities import KnownRequestParseError


def test_is_chunk_silent():
    rms_chunk = np.array([0, 1, 2, 3, 4])
    assert not sut.is_chunk_silent(rms_chunk, 1)


def test_is_chunk_silent_respects_absolute_threshold():
    rms_chunk = np.array([1e-10, 1e-10, 1e-10])
    assert sut.is_chunk_silent(rms_chunk, 1)


def test_is_chunk_silent_respects_adaptive_threshold():
    rms_chunk = np.array([0, 1, 2, 3, 4])
    assert sut.is_chunk_silent(rms_chunk, 3)


def test_featurize_chroma_chunk():
    rng = np.random.RandomState(42)
    chroma_chunk = rng.uniform(0, 1, size=(5, 12))
    expected = np.array([0.515988, 0.364336, 0.513337, 0.403389, 0.540451])
    actual = sut.featurize_chroma_chunk(chroma_chunk)
    assert np.allclose(expected, actual, atol=1e-5)


def test_featurize_file(saved_audio_file):
    df = sut.featurize_file(saved_audio_file)
    assert df.shape == (8, 14)

    chroma_feature_names = [
        'chroma-' + note
        for note in ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B']
    ]
    expected_feature_names = chroma_feature_names + ['time_offset', 'is_silent']
    for feature_name in expected_feature_names:
        assert feature_name in df, f'Expected "{feature_name}" column in the data frame'

    for chroma_feature in chroma_feature_names:
        values = df[chroma_feature]
        assert min(values) >= 0
        assert max(values) <= 1


def test_featurize_file_nonexistent(nonexistent_audio_file):
    msg = 'Cannot load audio file. Error: .* No such file or directory'
    with pytest.raises(KnownRequestParseError, match=msg):
        sut.featurize_file(nonexistent_audio_file)


def test_featurize_file_non_audio(saved_non_audio_file):
    msg = 'Cannot load audio file. Error: NoBackendError'
    with pytest.raises(KnownRequestParseError, match=msg):
        sut.featurize_file(saved_non_audio_file)
