#!/usr/bin/env python3
"""
Can be used as a template to generate chord annotation files based on
a known Guitar Pro file structure defined in constants below.
"""
import pandas as pd


# Names of chords defined in the Guitar Pro file.
# The order of items in this list should match the order of chords in the file.
CHORD_NAMES = [
    'C', 'D', 'E', 'F', 'G', 'A', 'B',
    'Cm', 'Dm', 'Em', 'Fm', 'Gm', 'Am', 'Bm',
]

# Each chord has BARS_PER_CHORD bar containing examples of this chord.
BARS_PER_CHORD = 5

# Based on the file tempo, each file takes SECONDS_PER_BAR seconds.
SECONDS_PER_BAR = 4

# Extract audio subsets relative to the beginning of the bar using these offsets (in seconds).
SEGMENTS_IN_CHORD = [[0.1, 0.6], [0.75, 1.25], [1.75, 2.25]]


def main():
    rows = []

    for chord_ix, chord_name in enumerate(CHORD_NAMES):
        for bar_ix in range(BARS_PER_CHORD):
            for segment in SEGMENTS_IN_CHORD:
                seconds_start = (
                    chord_ix * BARS_PER_CHORD * SECONDS_PER_BAR
                    + bar_ix * SECONDS_PER_BAR
                    + segment[0]
                )
                seconds_end = seconds_start + (segment[1] - segment[0])
                rows.append([seconds_start, seconds_end, chord_name])

    df = pd.DataFrame(rows, columns=['seconds_start', 'seconds_end', 'chord'])
    df.to_csv('example.labels', header=True, index=None, float_format='%06.2f')


if __name__ == '__main__':
    main()
