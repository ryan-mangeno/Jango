#!/bin/bash
PROJECT_ROOT="$(pwd)"
BASE_DIR="${PROJECT_ROOT}/Crimson/vendor/PhysX"
PHYSX_ROOT="${BASE_DIR}/physx"
PXSHARED_PATH="${BASE_DIR}/PxShared"
CMAKE_MODULES="${BASE_DIR}/externals/cmakemodules"

PHYSX_BUILD="${PHYSX_ROOT}/compiler/mac-arm64-native"
ABS_OUTPUT_DIR="${PHYSX_ROOT}/bin/mac.arm64"

echo "--- Building Minimal PhysX (M1 Native) ---"

if [ ! -d "$CMAKE_MODULES" ]; then
    pushd "$PHYSX_ROOT" > /dev/null
    echo "1" | ./generate_projects.sh
    popd > /dev/null
fi

export LC_ALL=C 

find "$BASE_DIR" -type f \( -name "*.cmake" -o -name "CMakeLists.txt" \) -exec sed -i '' 's/-Werror//g' {} +
find "$BASE_DIR" -type f \( -name "*.cmake" -o -name "CMakeLists.txt" \) -exec sed -i '' 's/-msse2//g' {} +
find "$BASE_DIR" -type f \( -name "*.cmake" -o -name "CMakeLists.txt" \) -exec sed -i '' 's/-m64//g' {} +

rm -rf "$PHYSX_BUILD"
mkdir -p "$PHYSX_BUILD"
mkdir -p "$ABS_OUTPUT_DIR"

cmake -S "${PHYSX_ROOT}/compiler/public" -B "$PHYSX_BUILD" \
      -G "Xcode" \
      -DTARGET_BUILD_PLATFORM=mac \
      -DPX_OUTPUT_ARCH=arm64 \
      -DCMAKE_OSX_ARCHITECTURES=arm64 \
      -DPHYSX_ROOT_DIR="$PHYSX_ROOT" \
      -DPXSHARED_PATH="$PXSHARED_PATH" \
      -DCMAKEMODULES_PATH="$CMAKE_MODULES" \
      -DPX_OUTPUT_LIB_DIR="$ABS_OUTPUT_DIR" \
      -DPX_OUTPUT_BIN_DIR="$ABS_OUTPUT_DIR" \
      -DPX_GENERATE_STATIC_LIBRARIES=ON \
      -DPX_SIMD=0 \
      -DCMAKE_CXX_FLAGS="-arch arm64 -D_DEBUG -Wno-everything" \
      -Wno-dev

if [ $? -eq 0 ]; then
    echo "Configuration successful. Building..."
    cmake --build "$PHYSX_BUILD" --config debug
else
    echo "Configuration failed."
    exit 1
fi
