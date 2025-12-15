#!/bin/bash

PROJECT_ROOT="$(pwd)"

echo "------------------------------------------------"
echo "Project Root: $PROJECT_ROOT"
echo "------------------------------------------------"

if ! command -v brew &> /dev/null; then
    echo "Error: Homebrew is required."
    exit 1
fi

BASE_NVIDIA_DIR="${PROJECT_ROOT}/Crimson/vendor/Nvidia-PhysX"
PHYSX_ROOT="${BASE_NVIDIA_DIR}/physx"
PXSHARED_ROOT="${BASE_NVIDIA_DIR}/PxShared"
EXTERNALS_ROOT="${BASE_NVIDIA_DIR}/externals"
CMAKE_MODULES_PATH="${EXTERNALS_ROOT}/cmakemodules"

PHYSX_SOURCE="${PHYSX_ROOT}/compiler/public"
PHYSX_BUILD="${PHYSX_ROOT}/compiler/mac64"

# check submdules
if [ ! -d "$PXSHARED_ROOT" ]; then
    echo "Error: 'PxShared' folder is missing!"
    echo "   Expected at: $PXSHARED_ROOT"
    echo "   Attempting to fetch via git..."
    git submodule update --init --recursive
    
    if [ ! -d "$PXSHARED_ROOT" ]; then
        echo "Critical Failure: Your git submodule is incomplete."
        echo "   Please check 'Crimson/vendor/Nvidia-PhysX' manually."
        exit 1
    fi
fi

# check external deps (Packman)
if [ ! -d "$CMAKE_MODULES_PATH" ]; then
    echo "PhysX dependencies (externals/cmakemodules) missing."
    echo "   Running Nvidia generate_projects to fetch them via Packman..."
    
    pushd "$PHYSX_ROOT" > /dev/null
    
    if [ -f "./generate_projects.sh" ]; then
        chmod +x ./generate_projects.sh
        ./generate_projects.sh mac checked
    else
        echo "Error: Could not find 'generate_projects.sh' in $PHYSX_ROOT"
        exit 1
    fi
    
    popd > /dev/null
fi

if [ ! -d "$CMAKE_MODULES_PATH" ]; then
    echo "Error: Packman failed. '$CMAKE_MODULES_PATH' still does not exist."
    exit 1
fi

echo "Patching PhysX CMake files..."

find "$PHYSX_ROOT/source/compiler/cmake" -type f \( -name "*.cmake" -o -name "CMakeLists.txt" \) -exec sed -i '' 's/-Werror//g' {} +

MAIN_CMAKE="$PHYSX_ROOT/source/compiler/cmake/CMakeLists.txt"
if [ -f "$MAIN_CMAKE" ]; then
    if ! grep -q "add_compile_options(-w)" "$MAIN_CMAKE"; then
        echo "" >> "$MAIN_CMAKE"
        echo "# PATCH: Silence all warnings forcefully" >> "$MAIN_CMAKE"
        echo "add_compile_options(-w)" >> "$MAIN_CMAKE"
        echo "   Injected 'add_compile_options(-w)' into main CMakeLists.txt"
    fi
fi

echo "Wiping old CMake cache..."
if [ -d "$PHYSX_BUILD" ]; then rm -rf "$PHYSX_BUILD"; fi
mkdir -p "$PHYSX_BUILD"
mkdir -p "$PHYSX_ROOT/bin/mac.x86_64"

echo "Configuring PhysX (Unix Makefiles)..."

cmake -S "$PHYSX_SOURCE" -B "$PHYSX_BUILD" \
      -G "Unix Makefiles" \
      -DTARGET_BUILD_PLATFORM=mac \
      -DPX_OUTPUT_ARCH=x86 \
      -DCMAKE_BUILD_TYPE=Debug \
      -DCMAKE_C_COMPILER=/usr/bin/clang \
      -DCMAKE_CXX_COMPILER=/usr/bin/clang++ \
      -DPHYSX_ROOT_DIR="$PHYSX_ROOT" \
      -DPXSHARED_PATH="$PXSHARED_ROOT" \
      -DPXSHARED_ROOT_DIR="$PXSHARED_ROOT" \
      -DCMAKEMODULES_PATH="$CMAKE_MODULES_PATH" \
      -DPX_OUTPUT_LIB_DIR="$PHYSX_ROOT/bin/mac.x86_64" \
      -DPX_OUTPUT_BIN_DIR="$PHYSX_ROOT/bin/mac.x86_64"

if [ $? -ne 0 ]; then
    echo "Error: PhysX configuration failed."
    exit 1
fi

echo "PhysX Configured. Building..."
cmake --build "$PHYSX_BUILD" -- -j4 > /dev/null 2>&1

if [ $? -eq 0 ]; then
    echo "Build Succeeded!"
else
    echo "Build Failed."
    echo "   Run the command again without '> /dev/null' to see errors."
    exit 1
fi


echo "--- Setup Complete ---"