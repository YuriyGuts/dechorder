#!/usr/bin/env bash

# DummyPredictionService: random predictions
# DataRobotV1APIPredictionService: DataRobot Prediction API v1.0 predictions
# EmbeddedPredictionService: predictions from a built-in neural network
export DECHORDER_PREDICTION_SERVICE=EmbeddedPredictionService

# DataRobot parameters
export DATAROBOT_SERVER="https://<ENTER-URL-HERE>.datarobot.com"
export DATAROBOT_SERVER_KEY="<ENTER-DATAROBOT-KEY-HERE>"
export DATAROBOT_DEPLOYMENT_ID="<ENTER-DEPLOYMENT-ID-HERE>"
export DATAROBOT_USERNAME="<ENTER-USERNAME-HERE>"
export DATAROBOT_API_TOKEN="<ENTER-API-TOKEN-HERE>"

# Flask parameters
export FLASK_APP=api.py
export FLASK_ENV=development
export FLASK_RUN_HOST=127.0.0.1
export FLASK_RUN_PORT=5000
export FLASK_UPLOAD_FOLDER=upload

export PYTHONPATH="$(dirname "$(pwd)")":${PYTHONPATH}

mkdir -p ${FLASK_UPLOAD_FOLDER}
flask run
