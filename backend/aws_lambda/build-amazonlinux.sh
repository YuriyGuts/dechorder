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
LLVM_VERSION=RELEASE_601/final

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
NUM_CPUS=$(cat /proc/cpuinfo | awk '/^processor/{print $3}' | wc -l)
CMAKE_BUILD_VARS="-DCMAKE_BUILD_TYPE=MinSizeRel -DLLVM_TARGETS_TO_BUILD=X86 -DLLVM_INCLUDE_EXAMPLES=OFF -DLLVM_INCLUDE_BENCHMARKS=OFF -DLLVM_PARALLEL_COMPILE_JOBS=${NUM_CPUS} -DLLVM_PARALLEL_LINK_JOBS=${NUM_CPUS}"
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
LIB_DIR="${VIRTUAL_ENV}/lib/python${PYTHON_VERSION}/site-packages/lib/"
mkdir -p "${LIB_DIR}"
cp /usr/lib64/atlas/* ${LIB_DIR}
cp /usr/lib64/libquadmath.so.0 ${LIB_DIR}
cp /usr/lib64/libgfortran.so.3 ${LIB_DIR}

log_stage "Installing Python packages"
# Install packages to the current folder, without building wheels. Order is important.
pip install --no-binary :all: -r ${BUILD_DIR}/include/requirements.txt

log_stage "Copying FFmpeg binaries"
cp ${FFMPEG_BIN_DIR}/ffmpeg ${VIRTUAL_ENV}/lib/python${PYTHON_VERSION}/site-packages/
cp ${FFMPEG_BIN_DIR}/lame ${VIRTUAL_ENV}/lib/python${PYTHON_VERSION}/site-packages/

log_stage "Copying additional modules from the host"
cp ${BUILD_DIR}/include/* ${VIRTUAL_ENV}/lib/python${PYTHON_VERSION}/site-packages/

# Remove symbols from .so files to reduce deployment package size.
log_stage "Removing symbols from .so files to reduce deployment package size"
find ${VIRTUAL_ENV}/lib/python${PYTHON_VERSION}/site-packages/ -name "*.so" | xargs strip

# Create Lambda deployment artifact by zipping up the packages in virtualenv.
log_stage "Creating Lambda deployment package"
pushd ${VIRTUAL_ENV}/lib/python${PYTHON_VERSION}/site-packages/ && zip -r -9 -q ${BUILD_DIR}/${ARTIFACT_NAME} * ; popd
