#!/usr/bin/env bash

# ==================================================================
# Deploys a previously built AWS Lambda artifact to production
# ==================================================================

# Name of AWSCLI profile to use.
AWS_PROFILE=${AWS_PROFILE:-personal}

# Intermediate S3 bucket used for uploading the package.
DECHORDER_S3_BUCKET=${DECHORDER_S3_BUCKET:-ygdata-private}

# Path on the host machine where the package is stored.
HOST_BUILD_DIR=$(pwd)/build

# Name of the AWS Lambda artifact file.
ARTIFACT_NAME=lambda_function.zip

# Name of the AWS Lambda function to update with this deployment.
LAMBDA_FUNCTION_NAME=DechorderRecognize

# ==================================================================
# End Config
# ==================================================================

SCRIPT_PATH=`realpath $0`
SCRIPT_DIR=`dirname ${SCRIPT_PATH}`
ARTIFACT_FULL_PATH=${HOST_BUILD_DIR}/${ARTIFACT_NAME}

log_stage() {
    local LINE=`printf '=%.0s' {1..70}`
    local DATE=`date '+%Y-%m-%d %H:%M:%S'`
    tput setaf 2; tput bold; echo ${LINE}; echo "[${DATE}] $1"; echo ${LINE}; tput sgr 0
}

log_stage "Uploading package to S3"
aws s3 cp ${ARTIFACT_FULL_PATH} s3://${DECHORDER_S3_BUCKET}/dechorder/${ARTIFACT_NAME}

log_stage "Deploying package to Lambda"
aws lambda update-function-code --profile ${AWS_PROFILE} --function-name ${LAMBDA_FUNCTION_NAME} --s3-bucket ${DECHORDER_S3_BUCKET} --s3-key dechorder/${ARTIFACT_NAME}
