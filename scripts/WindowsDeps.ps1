# --------------------------------------
# Fail fast
# --------------------------------------
$ErrorActionPreference = "Stop"
Write-Host "--- PhysX Windows Build Script ---"

# --------------------------------------
# Detect repo root (one level above scripts folder)
# --------------------------------------
$SCRIPT_DIR = Split-Path -Parent $MyInvocation.MyCommand.Path
$PROJECT_ROOT = Split-Path -Parent $SCRIPT_DIR

# --------------------------------------
# Paths
# --------------------------------------
$BASE_DIR       = Join-Path $PROJECT_ROOT "Crimson/vendor/PhysX"
$PHYSX_ROOT     = Join-Path $BASE_DIR "physx"
$PXSHARED_PATH  = Join-Path $BASE_DIR "PxShared"
$CMAKE_MODULES  = Join-Path $BASE_DIR "externals/cmakemodules"

$PHYSX_BUILD    = Join-Path $PHYSX_ROOT "compiler/windows-x64"
$ABS_OUTPUT_DIR = Join-Path $PHYSX_ROOT "bin/win.x64"

# Convert all paths to forward slashes for CMake
$PHYSX_ROOT_CMAKE    = $PHYSX_ROOT -replace '\\','/'
$PXSHARED_PATH_CMAKE = $PXSHARED_PATH -replace '\\','/'
$CMAKE_MODULES_CMAKE = $CMAKE_MODULES -replace '\\','/'
$PHYSX_BUILD_CMAKE   = $PHYSX_BUILD -replace '\\','/'
$ABS_OUTPUT_DIR_CMAKE= $ABS_OUTPUT_DIR -replace '\\','/'

# --------------------------------------
# Prerequisites
# --------------------------------------
Write-Host "--- Checking prerequisites ---"

foreach ($tool in @("cmake")) {
    if (-not (Get-Command $tool -ErrorAction SilentlyContinue)) {
        throw "Required tool not found on PATH: $tool"
    }
}

if (-not (Get-Command cl.exe -ErrorAction SilentlyContinue)) {
    throw "MSVC compiler not found. Run from a Visual Studio Developer PowerShell."
}

# --------------------------------------
# VCPKG_ROOT
# --------------------------------------
if (-not $env:VCPKG_ROOT) {
    Write-Warning "VCPKG_ROOT not set. Defaulting to VS2022 vcpkg location."
    $env:VCPKG_ROOT = "C:\Program Files\Microsoft Visual Studio\2022\Community\VC\vcpkg"
}

# --------------------------------------
# Install Assimp via vcpkg if missing
# --------------------------------------
$assimpInstalled = Test-Path (Join-Path $env:VCPKG_ROOT "installed/x64-windows/include/assimp")
if (-not $assimpInstalled) {
    Write-Host "Assimp not found. Installing via vcpkg..."
    Push-Location $env:VCPKG_ROOT
    .\vcpkg install assimp:x64-windows
    .\vcpkg integrate install
    Pop-Location
} else {
    Write-Host "Assimp already installed (vcpkg)"
}

# --------------------------------------
# Generate PhysX project files if missing
# --------------------------------------
if (-not (Test-Path $CMAKE_MODULES)) {
    Write-Host "Generating PhysX project files..."
    if (-not (Test-Path $PHYSX_ROOT)) {
        throw "PhysX folder not found at $PHYSX_ROOT. Did you initialize submodules?"
    }
    Push-Location $PHYSX_ROOT
    cmd /c "echo 1 | generate_projects.bat"
    Pop-Location
}

# --------------------------------------
# Strip unsupported compiler flags
# --------------------------------------
Write-Host "Stripping unsupported compiler flags..."

Get-ChildItem $BASE_DIR -Recurse -Include *.cmake, CMakeLists.txt |
ForEach-Object {
    (Get-Content $_.FullName) `
        -replace "-Werror", "" `
        -replace "-msse2", "" `
        -replace "-m64", "" |
    Set-Content $_.FullName
}

# --------------------------------------
# Prepare build directories
# --------------------------------------
if (Test-Path $PHYSX_BUILD) { Remove-Item $PHYSX_BUILD -Recurse -Force }
New-Item $PHYSX_BUILD -ItemType Directory | Out-Null
New-Item $ABS_OUTPUT_DIR -ItemType Directory -Force | Out-Null

# --------------------------------------
# Configure PhysX with CMake
# --------------------------------------
Write-Host "--- Configuring PhysX ---"

cmake `
    -S "$PHYSX_ROOT_CMAKE/compiler/public" `
    -B "$PHYSX_BUILD_CMAKE" `
    -G "Visual Studio 17 2022" `
    -A x64 `
    -DTARGET_BUILD_PLATFORM=windows `
    -DPX_OUTPUT_ARCH=x64 `
    -DPHYSX_ROOT_DIR="$PHYSX_ROOT_CMAKE" `
    -DPXSHARED_PATH="$PXSHARED_PATH_CMAKE" `
    -DCMAKEMODULES_PATH="$CMAKE_MODULES_CMAKE" `
    -DPX_OUTPUT_LIB_DIR="$ABS_OUTPUT_DIR_CMAKE" `
    -DPX_OUTPUT_BIN_DIR="$ABS_OUTPUT_DIR_CMAKE" `
    -DPX_GENERATE_STATIC_LIBRARIES=ON `
    -DPX_SIMD=0 `
    -DCMAKE_CXX_FLAGS="/D_DEBUG /W0"

# --------------------------------------
# Build
# --------------------------------------
Write-Host "--- Building PhysX (Debug) ---"
cmake --build "$PHYSX_BUILD_CMAKE" --config Debug

Write-Host "PhysX build completed successfully."
