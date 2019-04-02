#!/usr/bin/env bash

# ==============================================================
# Runs inside an Amazon Linux Docker container and builds an
# AWS Lambda deployment package properly linked to native libs
# ==============================================================

# Path in docker container's local filesystem to store outputs (should be mounted to a host directory)
BUILD_DIR=/build

# Name of the file that will be deployed to AWS Lambda.
ARTIFACT_NAME=lambda_function.zip
PYTHON_VERSION=3.7

# Versions of low-level dependencies used for building Python packages.
CMAKE_VERSION=3.14.1
LLVM_VERSION=RELEASE_701/final

# ==================================================================
# End Config
# ==================================================================

log_stage() {
    local LINE=`printf '=%.0s' {1..70}`
    local DATE=`date '+%Y-%m-%d %H:%M:%S'`
    tput setaf 6; tput bold; echo ${LINE}; echo "[${DATE}] $1"; echo ${LINE}; tput sgr 0
}

log_stage "Installing basic yum packages"
yum -y update
yum -y install nano wget

log_stage "Installing ATLAS and LAPACK"
yum -y install atlas-devel atlas-sse3-devel blas-devel lapack-devel

log_stage "Installing CMake"
mkdir -p ${BUILD_DIR}/cmake
cd ${BUILD_DIR}/cmake
wget https://github.com/Kitware/CMake/releases/download/v${CMAKE_VERSION}/cmake-${CMAKE_VERSION}.tar.gz
tar xzvf cmake-${CMAKE_VERSION}.tar.gz
cd cmake-${CMAKE_VERSION}
log_stage "[1/3] CMake bootstrap"
./bootstrap
log_stage "[2/3] CMake build"
make
log_stage "[3/3] CMake install"
make install

log_stage "Installing FFmpeg"
FFMPEG_BIN_DIR=${BUILD_DIR}/ffmpeg/bin
FFMPEG_BUILD_DIR=${BUILD_DIR}/ffmpeg/build
FFMPEG_SOURCE_DIR=${BUILD_DIR}/ffmpeg/source
mkdir -p ${FFMPEG_BIN_DIR}
mkdir -p ${FFMPEG_BUILD_DIR}
mkdir -p ${FFMPEG_SOURCE_DIR}
export PATH="${FFMPEG_BIN_DIR}:$PATH"

log_stage "[1/3] Build NASM"
cd ${FFMPEG_SOURCE_DIR}
curl -O -L https://www.nasm.us/pub/nasm/releasebuilds/2.14.02/nasm-2.14.02.tar.bz2
tar xjvf nasm-2.14.02.tar.bz2
cd nasm-2.14.02
./autogen.sh
./configure --prefix="${FFMPEG_BUILD_DIR}" --bindir="${FFMPEG_BIN_DIR}"
make
make install

log_stage "[2/3] Build LAME"
cd ${FFMPEG_SOURCE_DIR}
curl -O -L https://downloads.sourceforge.net/project/lame/lame/3.100/lame-3.100.tar.gz
tar xzvf lame-3.100.tar.gz
cd lame-3.100
./configure --prefix="${FFMPEG_BUILD_DIR}" --bindir="${FFMPEG_BIN_DIR}" --disable-shared --enable-nasm
make
make install

log_stage "[3/3] Build FFmpeg"
cd ${FFMPEG_SOURCE_DIR}
curl -O -L https://ffmpeg.org/releases/ffmpeg-snapshot.tar.bz2
tar xjvf ffmpeg-snapshot.tar.bz2
cd ffmpeg
PKG_CONFIG_PATH="$HOME/ffmpeg_build/lib/pkgconfig" ./configure \
  --prefix="${FFMPEG_BUILD_DIR}" \
  --pkg-config-flags="--static" \
  --extra-cflags="-I${FFMPEG_BUILD_DIR}/include" \
  --extra-ldflags="-L${FFMPEG_BUILD_DIR}/lib" \
  --extra-libs=-lpthread \
  --extra-libs=-lm \
  --bindir="${FFMPEG_BIN_DIR}" \
  --enable-gpl \
  --enable-libmp3lame \
  --enable-nonfree
make
make install
hash -d ffmpeg

log_stage "Installing LLVM"
mkdir -p ${BUILD_DIR}/llvm
cd ${BUILD_DIR}/llvm
svn co http://llvm.org/svn/llvm-project/llvm/tags/${LLVM_VERSION} source
mkdir -p ${BUILD_DIR}/llvm/build
cd ${BUILD_DIR}/llvm/build
CMAKE_BUILD_VARS="-DCMAKE_BUILD_TYPE=MinSizeRel -DLLVM_TARGETS_TO_BUILD=X86 -DLLVM_INCLUDE_EXAMPLES=OFF -DLLVM_INCLUDE_BENCHMARKS=OFF"
log_stage "[1/3] LLVM bootstrap"
cmake ${CMAKE_BUILD_VARS} ${BUILD_DIR}/llvm/source
log_stage "[2/3] LLVM build"
cmake ${CMAKE_BUILD_VARS} --build .
log_stage "[3/3] LLVM install"
cmake --build . --target install

log_stage "Creating a virtualenv for building packages"
cd ${BUILD_DIR}
python -m venv --copies dechorder-env
source dechorder-env/bin/activate

log_stage "Copying shared libraries to virtualenv"
SITE_PACKAGES_DIR="${VIRTUAL_ENV}/lib/python${PYTHON_VERSION}/site-packages"
SITE_PACKAGES_BIN_DIR="${SITE_PACKAGES_DIR}/bin"
SITE_PACKAGES_LIB_DIR="${SITE_PACKAGES_DIR}/lib"
mkdir -p "${SITE_PACKAGES_BIN_DIR}"
mkdir -p "${SITE_PACKAGES_LIB_DIR}"
rsync -LIPavz "/usr/lib64/atlas/" --include "*.so.3" --exclude "*" "${SITE_PACKAGES_LIB_DIR}/"
rsync -LIPavz "/usr/lib64/libquadmath.so.0" "${SITE_PACKAGES_LIB_DIR}/"
rsync -LIPavz "/usr/lib64/libgfortran.so.3" "${SITE_PACKAGES_LIB_DIR}/"

log_stage "Installing Python packages"
# Install packages to the current folder, without building wheels. Order is important.
pip install --no-binary :all: -r ${BUILD_DIR}/requirements.txt

log_stage "Copying FFmpeg binaries"
rsync -IPavz "${FFMPEG_BIN_DIR}/ffmpeg" "${SITE_PACKAGES_BIN_DIR}/"
rsync -IPavz "${FFMPEG_BIN_DIR}/lame" "${SITE_PACKAGES_BIN_DIR}/"

log_stage "Copying additional modules from the host"
rsync -IPavz "${BUILD_DIR}/include/" "${SITE_PACKAGES_DIR}/"

log_stage "Removing symbols from .so files to reduce deployment package size"
find "${SITE_PACKAGES_DIR}/" -name "*.so" -exec echo "{}" \; -exec strip "{}" \;

log_stage "Removing unnecessary files from pip packages to reduce deployment package size"
find "${SITE_PACKAGES_DIR}/" -name "tests" -type d -prune -exec echo "{}" \; -exec rm -rf "{}" \;
rm -rf "${SITE_PACKAGES_DIR}/joblib/test"
rm -rf "${SITE_PACKAGES_DIR}/librosa/util/example_data/*"

# Create Lambda deployment artifact by zipping up the packages in virtualenv.
log_stage "Creating Lambda deployment package"
pushd "${SITE_PACKAGES_DIR}/" && zip -r -9 -q ${BUILD_DIR}/${ARTIFACT_NAME} * ; popd
