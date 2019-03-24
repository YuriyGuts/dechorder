from common.features import featurize_file


def recognize_saved_file(path, prediction_service):
    exclude_columns = ['time_offset', 'is_silent']
    df_features = featurize_file(path)

    # Prepare dataset for predictions. This involves removing features we use for internal purposes.
    df_features_not_silent = df_features[~df_features['is_silent']]
    df_features_pred = df_features_not_silent.drop(columns=exclude_columns)
    df_predictions = prediction_service.predict(df_features_pred)

    # Attach some of the information we removed earlier.
    df_predictions['time_offset'] = df_features_not_silent.reset_index(drop=True)['time_offset']

    # Final smoothing and post-processing.
    result = df_predictions.rename(columns={'time_offset': 'timeOffset'}).to_dict(orient='records')
    result = remove_repeating_chords(result)
    return result


def remove_repeating_chords(chords):
    result = []
    prev_chord = None
    for chord in chords:
        if chord['name'] != prev_chord:
            result.append(chord)
            prev_chord = chord['name']
    return result
