import librosa
import numpy as np
import pandas as pd


# Resample all uploaded files to this sample rate. Ideally, should match the SR used for training.
SUPPORTED_SAMPLE_RATE = 22050

# Duration of a single unit of recognition. The input file will be split to chunks of this size.
SECONDS_PER_CHUNK = 1.0

# Signal with RMS lower than this value will be considered silence.
ABSOLUTE_SILENCE_RMS_THRESHOLD = 1e-5

# Signal with RMS lower than this percentile in the input file will be considered silence.
ADAPTIVE_SILENCE_RMS_PERCENTILE = 25


def is_chunk_silent(chunk, adaptive_threshold):
    mean_rms = np.mean(chunk)
    return mean_rms < ABSOLUTE_SILENCE_RMS_THRESHOLD or mean_rms < adaptive_threshold


def featurize_chroma_chunk(chunk):
    return np.mean(chunk, axis=1)


def featurize_file(filename):
    signal, sample_rate = librosa.load(filename, sr=SUPPORTED_SAMPLE_RATE)
    duration = len(signal) / sample_rate

    spectrogram = np.abs(librosa.stft(signal))
    spectrogram_per_second = spectrogram.shape[1] / duration
    rms = librosa.feature.rms(S=spectrogram).T.ravel()
    chroma = librosa.feature.chroma_stft(S=spectrogram, sr=sample_rate)
    adaptive_rms_threshold = np.percentile(rms, ADAPTIVE_SILENCE_RMS_PERCENTILE)

    chunk_split_points = np.arange(0, chroma.shape[-1], spectrogram_per_second * SECONDS_PER_CHUNK)
    chunk_split_points = np.round(chunk_split_points).astype(int)[1:-1]
    rms_chunks = np.split(rms, chunk_split_points)
    chroma_chunks = np.split(chroma, chunk_split_points, axis=1)
    time_markers = np.arange(0, len(chroma_chunks)) * SECONDS_PER_CHUNK

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

    df = pd.DataFrame(features, columns=feature_names)
    df['time_offset'] = np.array(time_markers)
    df['is_silent'] = np.array(is_silent)
    return df
