#!/bin/bash
set -e

BUILD_DIR="build"
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

echo "Generating Stubs ..."
python3 "$ROOT_DIR/scripts/generate_backend_stubs.py"

echo "Configuring build"

if [ -d "$BUILD_DIR" ]; then
    rm -rf "$BUILD_DIR"
fi

cd $ROOT_DIR
cmake -B build -DCMAKE_BUILD_TYPE=Debug

echo "Generation successful."
echo "Run: cmake --build build -j 4"
