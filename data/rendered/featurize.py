#!/usr/bin/env python3
"""
Generates a modeling-ready dataset from audio files and annotations.
Each audio file must have a corresponding .labels file.

Usage: featurize.py [-h] --output CSV-FILE INPUT-PATTERN

positional arguments:
  INPUT-PATTERN      input audio files or wildcards

optional arguments:
  -h, --help         show the help message and exit
  --output CSV-FILE  name of the CSV file to save results to

Example: featurize.py --output dataset.csv *.mp3
"""
import argparse
import os
import sys

import librosa
import numpy as np
import pandas as pd


def parse_command_line_args(args):
    program_desc = 'Generate a modeling-ready dataset from audio files and annotations.'
    parser = argparse.ArgumentParser(description=program_desc)
    parser.add_argument(
        '--output',
        metavar='CSV-FILE',
        required=True,
        help='name of the CSV file to save results to',
    )
    parser.add_argument(
        'audio_filenames',
        help='input audio files or wildcards',
        metavar='INPUT-PATTERN',
        nargs='+'
    )
    return parser.parse_args(args)


def featurize_audio_segment(chroma):
    return np.mean(chroma, axis=1)


def featurize_file(audio_filename, label_filename):
    df_labels = pd.read_csv(label_filename)
    y, sr = librosa.load(audio_filename)
    S = np.abs(librosa.stft(y))
    chroma = librosa.feature.chroma_stft(S=S, sr=sr)

    file_duration = len(y) / sr
    chroma_per_second = chroma.shape[1] / file_duration

    features = []
    for idx, seconds_start, seconds_end, label in df_labels.itertuples():
        chroma_start_idx = int(np.round(seconds_start * chroma_per_second))
        chroma_end_idx = int(np.round(seconds_end * chroma_per_second))
        chroma_segment = chroma[:, chroma_start_idx:chroma_end_idx]
        features.append(featurize_audio_segment(chroma_segment))

    note_names = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B']
    feature_names = [f'chroma-{note}' for note in note_names]
    df = pd.DataFrame(features, columns=feature_names)
    df['chord'] = df_labels['chord']
    return df


def main():
    args = parse_command_line_args(sys.argv[1:])

    audio_filenames = args.audio_filenames
    output_filename = os.path.abspath(args.output)

    label_filenames = [
        f'{os.path.splitext(audio_filename)[0]}.labels'
        for audio_filename in audio_filenames
    ]

    missing_label_files = [
        label_filename
        for label_filename in label_filenames
        if not os.path.exists(label_filename)
    ]
    if missing_label_files:
        print('Error: expected the following annotation files but they were not found:')
        for missing_file in missing_label_files:
            print(missing_file)
        sys.exit(1)

    print(f'Collected {len(audio_filenames)} files')
    dataframes = []

    for audio_filename, label_filename in zip(audio_filenames, label_filenames):
        print(f'Featurizing "{audio_filename}"...', end='', flush=True)
        dataframes.append(featurize_file(audio_filename, label_filename))
        print(' Done')

    df_master = pd.concat(dataframes, axis=0)
    df_master.to_csv(output_filename, header=True, index=None, float_format='%.6f')
    print(f'Saved to {output_filename}')


if __name__ == '__main__':
    main()
