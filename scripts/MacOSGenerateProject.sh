#!/bin/bash

BUILD_DIR="build"

if [ ! -d "$BUILD_DIR" ]; then
    mkdir "$BUILD_DIR"
fi

cd "$BUILD_DIR"

BREW_PREFIX=$(brew --prefix)

cmake .. -G "Unix Makefiles" \
    -DCMAKE_BUILD_TYPE=Debug \
    -DCMAKE_PREFIX_PATH="$BREW_PREFIX"

if [ $? -eq 0 ]; then
    echo "Generation successful."
    echo "Run: cmake --build build -j 1"
else
    echo "Generation failed."
    exit 1
fi