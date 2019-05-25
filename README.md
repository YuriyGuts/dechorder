# Dechorder

Automatic chord recognition application powered by machine learning.

[Demo video on YouTube](https://www.youtube.com/watch?v=0i5GQrWegGI)

![image](https://user-images.githubusercontent.com/2750531/55685970-9ac95c00-5964-11e9-9fa0-55d7d805f85f.png)


## Overall Flow

1. User records an audio sample using a microphone on an iOS device.
2. The raw audio file is sent to the backend API (via HTTP file upload) for recognition.
3. The backend extracts features from the uploaded audio file and predicts chords in the file. Either a built-in model
   or an external machine learning service like DataRobot can be used for predictions depending on the configuration.
4. Chord annotations (time marker, chord name, confidence) are sent back from the API to the client.
5. The client app provides the user with a playback interface and allows fast-forwarding to particular chords.

## Deployment Options

1. Client: iPhone/iPad application running iOS 12+.
2. Server:
   * Python Flask application, or
   * AWS Lambda function running behind an AWS API Gateway

## Development

Not all dependencies are required for all development tasks but the complete list of additional components is provided below:

1. iOS App: CocoaPods + Swift packages from `Podfile`.
2. Backend: FFmpeg + Python packages from `requirements.txt`.
3. Data preparation tools: `sox`.
4. AWS Lambda deployment: `awscli`.

## Building

### Client: iOS App

The initial version of the app was built using Swift 2 and XCode 7, then upgraded to Swift 5 and XCode 10, with up-to-date CocoaPods packages at the time of writing.

### Server: AWS Lambda

An AWS Lambda deployment package for Dechorder is extremely tricky to build, due to multiple factors:

1. **Specific runtime environment**. At the time of writing this, [AWS Lambda execution environment](https://docs.aws.amazon.com/lambda/latest/dg/current-supported-versions.html) includes the following:
    * Operating system – Amazon Linux.
    * AMI – `amzn-ami-hvm-2018.03.0.20181129-x86_64-gp2`
    * Linux kernel – `4.14.94-73.73.amzn1.x86_64`
    * Python 3.7 SDK – `boto3-1.9.42 botocore-1.12.42`

2. **Binary dependencies**. Scientific libraries used in feature engineering require low-level linear algebra libraries, binary utilities, and JIT compilation, tailored to the specific runtime mentioned above. For example:
    * `numpy` and `scipy` require ATLAS and LAPACK.
    * `librosa` requires `numba`, which requires an exact version of `llvmlite`, which requires static linking to LLVM, which needs to be custom-built from source.
      - Warning: at the time of writing, SVN repo for LLVM is being deprecated, so the sources and build steps might need to be changed in case of upgrading Dechorder infrastructure.
    * MP3/M4A audio backends for `librosa` require FFmpeg command-line binary which needs to be custom-built from source.

3. **Package size limitations**. At the time of writing this, AWS Lambda requires the unpacked archive to be under 250 MB. At the same time, we have to bundle all binary dependencies mentioned above along with 15+ pip packages. As a result, we use the following tricks to reduce the package size:
    * LLVM is built only with X86 support and in minimum release size mode.
    * All installed pip packages are postprocessed: `.so` libraries are stripped of object/debug information, unit tests and example data are removed.
    * Static libraries (`.a`) are not included, only `.so` files.
    * The tricks above allow us to reach a deployment package size of ~160 MB.

Due to the factors above, the actual build is performed inside a Docker container running Amazon Linux with an environment similar to AWS Lambda runtime. When you run `build.sh`, it launches a Docker container and runs `build-amazonlinux.sh` inside it, mounting the host folder to store all artifacts.

## Deploying

### Server: AWS Lambda

1. Install Docker.
2. Run the following (might take a few hours to run):

    ```bash
    $ cd backend/aws_lambda
    $ ./build.sh
    ```

3. If you're using Linux, you might have to run `sudo chown -R $(whoami) build` afterwards as well to get the ownership back.
4. Run the following:

    ```bash
    $ cd backend/aws_lambda
    $ AWS_PROFILE=<your-awscli-profile-name> DECHORDER_S3_BUCKET=<your-bucket-name> ./deploy.sh
    ```

5. Your code (`lambda_function.zip`) should now be uploaded to an S3 bucket and deployed to AWS Lambda.
6. Configure the lambda function in AWS Management Console:
    * Customize the `PATH` environment variable to include the `bin` folder from the package:
      - `PATH`: `/var/task/bin:/var/lang/bin:/usr/local/bin:/usr/bin/:/bin:/opt/bin`
    * Customize the `DECHORDER_PREDICTION_SERVICE` environment variable:
      - For random predictions, specify `DummyPredictionService`
      - For using the built-in neural network classifier, specify `EmbeddedPredictionService`
      - For DataRobot Prediction API v1.0, specify `DataRobotV1APIPredictionService`
    * For using DataRobot Prediction API v1.0, you need a DataRobot account. Customize the following environment variables as well:
      - `DATAROBOT_SERVER`
      - `DATAROBOT_SERVER_KEY`
      - `DATAROBOT_DEPLOYMENT_ID`
      - `DATAROBOT_USERNAME`
      - `DATAROBOT_API_TOKEN`
