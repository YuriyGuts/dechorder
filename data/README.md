# Preparing Training Data

1. Export Guitar Pro files as WAV audio files, save them to `data/raw/*.wav`.
2. Convert the audio format for feature engineering:

        cd data/rendered
        ./standardize-audio-format.py ../raw/*.wav

3. For each generated `FILENAME.mp3` file, create a `FILENAME.labels` file. Run `generate-example-labels.py` to generate an example file.
4. Generate a modeling-ready dataset:

        ./featurize.py --output ../featurized/dataset.csv *.mp3

5. The dataset will be saved to `data/featurized/dataset.csv`.
