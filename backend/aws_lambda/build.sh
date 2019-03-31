#!/usr/bin/env bash

# ==================================================================
# Runs Amazon Linux in a Docker container and builds an AWS Lambda
# deployment package there, saving the results to local disk.
# ==================================================================

# Path on the host machine to store outputs (will be mounted to the container).
HOST_BUILD_DIR=$(pwd)/build

# Path in docker container's local filesystem to store outputs.
GUEST_BUILD_DIR=/build

# Name of the Docker image containing an AWS Lambda-like runtime.
DOCKER_IMAGE=lambci/lambda:build-python3.7

# ==================================================================
# End Config
# ==================================================================

SCRIPT_PATH=`realpath $0`
SCRIPT_DIR=`dirname ${SCRIPT_PATH}`

log_stage() {
    local LINE=`printf '=%.0s' {1..70}`
    local DATE=`date '+%Y-%m-%d %H:%M:%S'`
    tput setaf 2; tput bold; echo ${LINE}; echo "[${DATE}] $1"; echo ${LINE}; tput sgr 0
}

log_stage "Removing previous build outputs"
rm -rf ${HOST_BUILD_DIR}
mkdir -p ${HOST_BUILD_DIR}

log_stage "Copying build support files"
mkdir -p ${HOST_BUILD_DIR}/include
cp -r ${SCRIPT_DIR}/build-amazonlinux.sh ${HOST_BUILD_DIR}/
cp -r ${SCRIPT_DIR}/../common ${HOST_BUILD_DIR}/include
cp -r ${SCRIPT_DIR}/lambda_function.py ${HOST_BUILD_DIR}/include
cp -r ${SCRIPT_DIR}/requirements.txt ${HOST_BUILD_DIR}/

log_stage "Starting dockerized build"
docker run -v ${HOST_BUILD_DIR}:${GUEST_BUILD_DIR} -it ${DOCKER_IMAGE} bash ${GUEST_BUILD_DIR}/build-amazonlinux.sh

log_stage "Done. Check for errors in the output above"
