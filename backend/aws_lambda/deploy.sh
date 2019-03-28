#!/usr/bin/env bash

AWS_PROFILE=${AWS_PROFILE:-personal}
S3_BUCKET=ygdata-private

CURRENT_DIR=`pwd`
SCRIPT=`realpath $0`
LAMBDA_DIR=`dirname ${SCRIPT}`
BUILD_DIR=${LAMBDA_DIR}/build
ARTIFACT_NAME=lambda_function.zip
ARTIFACT_FULL_PATH=${BUILD_DIR}/${ARTIFACT_NAME}

echo "Preparing build directory"
rm -rf ${BUILD_DIR}
mkdir -p ${BUILD_DIR}
cd ${BUILD_DIR}

echo "Pulling 3rd-party dependencies for export"
pip install -r ${LAMBDA_DIR}/requirements.txt --target .
#find . | grep -E "(__pycache__|\.pyc|\.pyo$)" | xargs rm -rf

echo "Creating deployment package"
# 3rd-party pip packages.
zip -r9 ${ARTIFACT_FULL_PATH} .
# Common modules folder.
cd ../..
zip -r9 ${ARTIFACT_FULL_PATH} common
# Main lambda function.
zip -j9 ${ARTIFACT_FULL_PATH} ${LAMBDA_DIR}/lambda_function.py

echo "Uploading package to S3..."
aws s3 cp ${ARTIFACT_FULL_PATH} s3://${S3_BUCKET}/dechorder/${ARTIFACT_NAME}
echo "Deploying package to Lambda..."
aws lambda update-function-code --profile ${AWS_PROFILE} --function-name DechorderRecognize --s3-bucket ${S3_BUCKET} --s3-key dechorder/${ARTIFACT_NAME}

cd $CURRENT_DIR
