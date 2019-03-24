#!/usr/bin/env python3
"""
Batch convert audio files to a standardized efficient format that can
be read by audio feature engineering components (MP3, 11 kHz, 16 bit, mono).

Requires sox to be installed (apt install sox / brew install sox)

Usage: standardize-audio-format.py <pattern1> [<pattern2> ...]
Example: standardize-audio-format.py *.wav *.aiff *.flac
"""

import os
import subprocess
import sys


def print_usage():
    print('Usage: standardize-audio-format.py <pattern1> [<pattern2> ...]')
    print('Example: standardize-audio-format.py *.wav')


def get_program_output(command):
    return subprocess.getoutput(command)


def sox_exists():
    command_output = get_program_output('command -v sox')
    return len(command_output) > 0


def convert_file(input_filename):
    print(f'Converting "{input_filename}"...', end='', flush=True)
    basename = os.path.basename(input_filename)
    name = os.path.splitext(basename)[0]
    output_filename = f'{name}.mp3'
    get_program_output(f'sox {input_filename} {output_filename} rate 22050 channels 1')
    print(f' Done -> "{output_filename}"')


def main():
    if len(sys.argv) <= 1:
        print('Error: invalid number of arguments')
        print_usage()
        sys.exit(1)

    if not sox_exists():
        print('Error: sox utility must be installed.')
        print('Please install it with `apt install sox` / `brew install sox`')
        sys.exit(1)

    filenames = sys.argv[1:]
    print(f'Collected {len(filenames)} files')
    for input_filename in filenames:
        convert_file(input_filename)

if __name__ == '__main__':
    main()
