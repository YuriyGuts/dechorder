import logging

import librosa
import numpy as np
import pandas as pd

from common.utilities import KnownRequestParseError


logger = logging.getLogger(__name__)


# Resample all uploaded files to this sample rate. Ideally, should match the SR used for training.
SUPPORTED_SAMPLE_RATE = 22050

# Duration of a single unit of recognition. The input file will be split to chunks of this size.
SECONDS_PER_CHUNK = 1.0

# Signal with RMS lower than this value will be considered silence.
ABSOLUTE_SILENCE_RMS_THRESHOLD = 1e-5

# Signal with RMS lower than this percentile in the input file will be considered silence.
ADAPTIVE_SILENCE_RMS_PERCENTILE = 25


def is_chunk_silent(rms_chunk, adaptive_threshold):
    """
    Determines whether the specified audio segment is silent or not.

    Parameters
    ----------
    rms_chunk : numpy.array
        A 1D vector of RMS values for the chunk.
    adaptive_threshold : float
        An RMS threshold below which the audio is considered silent.

    Returns
    -------
    bool
    """
    mean_rms = np.mean(rms_chunk)
    return mean_rms < ABSOLUTE_SILENCE_RMS_THRESHOLD or mean_rms < adaptive_threshold


def featurize_chroma_chunk(chunk):
    """
    Extract features from a chromagram segment.

    Parameters
    ----------
    chunk : numpy.array
        A 2D array (*, 12) representing the chromagram for the chunk.

    Returns
    -------
    numpy.array
        Extracted 1D feature vector.
    """
    return np.mean(chunk, axis=1)


def featurize_file(filename):
    """
    Extracts audio features from the specified audio file.

    Parameters
    ----------
    filename : str
        Path to a saved audio file.

    Returns
    -------
    pandas.DataFrame
        A data frame with extracted audio features, one line for each SECONDS_PER_CHUNK seconds.
    """
    try:
        logger.info(f'Reading audio file: "{str(filename)}"')
        signal, sample_rate = librosa.load(filename, sr=SUPPORTED_SAMPLE_RATE)
    except Exception as e:
        error_desc = str(e) or e.__class__.__name__
        raise KnownRequestParseError('Cannot load audio file. Error: ' + error_desc)

    duration = len(signal) / sample_rate
    logger.info(f'File duration: {duration:.1f} seconds')

    spectrogram = np.abs(librosa.stft(signal))
    spectrogram_per_second = spectrogram.shape[1] / duration
    logger.info(f'Spectrogram shape: {spectrogram.shape}')

    rms = librosa.feature.rms(S=spectrogram).T.ravel()
    chroma = librosa.feature.chroma_stft(S=spectrogram, sr=sample_rate)
    adaptive_rms_threshold = np.percentile(rms, ADAPTIVE_SILENCE_RMS_PERCENTILE)

    # Split RMS and Chroma arrays into equally sized chunks, each taking SECONDS_PER_CHUNK.
    chunk_split_points = np.arange(0, chroma.shape[-1], spectrogram_per_second * SECONDS_PER_CHUNK)
    chunk_split_points = np.round(chunk_split_points).astype(int)[1:-1]
    rms_chunks = np.split(rms, chunk_split_points)
    chroma_chunks = np.split(chroma, chunk_split_points, axis=1)
    time_markers = np.arange(0, len(chroma_chunks)) * SECONDS_PER_CHUNK

    # Featurize each chunk, detect silence, and store the results as a DataFrame row.
    logger.info('Generating features')
    features = [
        featurize_chroma_chunk(chunk)
        for chunk in chroma_chunks
    ]
    feature_names = [
        'chroma-' + note
        for note in ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B']
    ]
    is_silent = [
        is_chunk_silent(chunk, adaptive_rms_threshold)
        for chunk in rms_chunks
    ]

    # Assemble results.
    df = pd.DataFrame(features, columns=feature_names)
    df['time_offset'] = np.array(time_markers)
    df['is_silent'] = np.array(is_silent)
    return df
