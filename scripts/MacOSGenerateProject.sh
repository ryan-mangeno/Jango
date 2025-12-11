#!/bin/bash

BUILD_DIR="build"

if ! command -v brew &> /dev/null; then
    echo "Error: Homebrew is required."
    exit 1
fi

if ! brew list assimp &>/dev/null; then
    echo "Installing assimp..."
    brew install assimp
fi

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