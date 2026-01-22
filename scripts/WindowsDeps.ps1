# -------------------------------------- 
# Fail fast 
# -------------------------------------- 
$ErrorActionPreference = "Stop"
Write-Host "--- Automated Dependency Setup Script ---" -ForegroundColor Cyan

# -------------------------------------- 
# Detect repo root
# -------------------------------------- 
$SCRIPT_DIR = Split-Path -Parent $MyInvocation.MyCommand.Path
$PROJECT_ROOT = Split-Path -Parent $SCRIPT_DIR

Write-Host "Project root: $PROJECT_ROOT" -ForegroundColor Green

# -------------------------------------- 
# VCPKG_ROOT
# -------------------------------------- 
if (-not $env:VCPKG_ROOT) {
    Write-Warning "VCPKG_ROOT not set. Defaulting to VS2022 vcpkg location."
    $env:VCPKG_ROOT = "C:\Program Files\Microsoft Visual Studio\2022\Community\VC\vcpkg"
}

if (-not (Test-Path $env:VCPKG_ROOT)) {
    throw "VCPKG_ROOT path does not exist: $env:VCPKG_ROOT"
}

Write-Host "Using vcpkg at: $env:VCPKG_ROOT" -ForegroundColor Green

# -------------------------------------- 
# Check vcpkg mode
# -------------------------------------- 
$isManifestOnly = $false
Push-Location $env:VCPKG_ROOT
try {
    $testResult = & .\vcpkg.exe list 2>&1 | Out-String
    if ($testResult -match "does not have a classic mode instance") {
        $isManifestOnly = $true
        Write-Host "Detected: vcpkg is manifest-mode only" -ForegroundColor Yellow
    }
} catch {
    Write-Warning "Could not determine vcpkg mode"
}
Pop-Location

# -------------------------------------- 
# Setup vcpkg dependencies
# -------------------------------------- 
if ($isManifestOnly) {
    Write-Host "`n--- Setting up vcpkg manifest mode ---" -ForegroundColor Cyan
    
    $vcpkgJsonPath = Join-Path $PROJECT_ROOT "vcpkg.json"
    
    Write-Host "Getting vcpkg baseline..." -ForegroundColor Yellow
    Push-Location $env:VCPKG_ROOT
    try {
        $baseline = git rev-parse HEAD 2>$null
    } catch {
        $baseline = $null
    }
    Pop-Location
    
    if (-not $baseline) {
        Write-Warning "Could not get git baseline. Using a recent known baseline."
        $baseline = "c8696863d371ab7f46e213d8f5ca923c4aef2a00"
    }
    
    Write-Host "Using baseline: $baseline" -ForegroundColor Green
    
    $vcpkgManifest = @{
        "name" = "jango"
        "version" = "1.0.0"
        "dependencies" = @(
            "assimp"
        )
        "builtin-baseline" = $baseline
    } | ConvertTo-Json -Depth 10
    
    if (Test-Path $vcpkgJsonPath) {
        Write-Host "vcpkg.json already exists. Backing up..." -ForegroundColor Yellow
        Copy-Item $vcpkgJsonPath "$vcpkgJsonPath.backup" -Force
    }
    
    Set-Content $vcpkgJsonPath $vcpkgManifest -Encoding UTF8
    Write-Host "Created vcpkg.json at: $vcpkgJsonPath" -ForegroundColor Green
    Write-Host "Dependencies will be installed automatically when CMake runs" -ForegroundColor Cyan
}

# -------------------------------------- 
# Paths 
# -------------------------------------- 
$BASE_DIR = Join-Path $PROJECT_ROOT "Crimson/vendor/PhysX"
$PHYSX_ROOT = Join-Path $BASE_DIR "physx"
$PXSHARED_PATH = Join-Path $BASE_DIR "PxShared"
$CMAKE_MODULES = Join-Path $BASE_DIR "externals/cmakemodules"
$PHYSX_BUILD = Join-Path $PHYSX_ROOT "compiler/windows-x64"
$ABS_OUTPUT_DIR = Join-Path $PHYSX_ROOT "bin/win.x64"
$VCPKG_TOOLCHAIN = Join-Path $env:VCPKG_ROOT "scripts/buildsystems/vcpkg.cmake"

$PHYSX_ROOT_CMAKE = $PHYSX_ROOT -replace '\\','/'
$PXSHARED_PATH_CMAKE = $PXSHARED_PATH -replace '\\','/'
$CMAKE_MODULES_CMAKE = $CMAKE_MODULES -replace '\\','/'
$PHYSX_BUILD_CMAKE = $PHYSX_BUILD -replace '\\','/'
$ABS_OUTPUT_DIR_CMAKE= $ABS_OUTPUT_DIR -replace '\\','/'
$VCPKG_TOOLCHAIN_CMAKE = $VCPKG_TOOLCHAIN -replace '\\','/'

# -------------------------------------- 
# Prerequisites 
# -------------------------------------- 
Write-Host "`n--- Checking prerequisites ---" -ForegroundColor Cyan

foreach ($tool in @("cmake", "git")) {
    if (-not (Get-Command $tool -ErrorAction SilentlyContinue)) {
        throw "Required tool not found on PATH: $tool"
    }
}

if (-not (Get-Command cl.exe -ErrorAction SilentlyContinue)) {
    throw "MSVC compiler not found. Run from a Visual Studio Developer PowerShell."
}

if (-not (Test-Path $VCPKG_TOOLCHAIN)) {
    throw "vcpkg toolchain file not found at: $VCPKG_TOOLCHAIN"
}

Write-Host "All prerequisites met" -ForegroundColor Green

# -------------------------------------- 
# Generate PhysX project files
# -------------------------------------- 
if (-not (Test-Path $CMAKE_MODULES)) {
    Write-Host "`n--- Generating PhysX project files ---" -ForegroundColor Cyan
    
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
Write-Host "`n--- Stripping unsupported compiler flags ---" -ForegroundColor Cyan

Get-ChildItem $BASE_DIR -Recurse -Include *.cmake,CMakeLists.txt -ErrorAction SilentlyContinue | ForEach-Object {
    try {
        $content = Get-Content $_.FullName
        $content = $content -replace "-Werror", ""
        $content = $content -replace "-msse2", ""
        $content = $content -replace "-m64", ""
        Set-Content $_.FullName $content
    } catch {
        Write-Warning "Could not process file: $($_.FullName)"
    }
}

# -------------------------------------- 
# Prepare build directories 
# -------------------------------------- 
Write-Host "`n--- Preparing build directories ---" -ForegroundColor Cyan

if (Test-Path $PHYSX_BUILD) {
    Remove-Item $PHYSX_BUILD -Recurse -Force
}

New-Item $PHYSX_BUILD -ItemType Directory -Force | Out-Null
New-Item $ABS_OUTPUT_DIR -ItemType Directory -Force | Out-Null

# -------------------------------------- 
# Configure PhysX
# -------------------------------------- 
Write-Host "`n--- Configuring PhysX ---" -ForegroundColor Cyan

$cmakeArgs = @(
    "-S", "$PHYSX_ROOT_CMAKE/compiler/public",
    "-B", "$PHYSX_BUILD_CMAKE",
    "-G", "Visual Studio 17 2022",
    "-A", "x64",
    "-DCMAKE_TOOLCHAIN_FILE=$VCPKG_TOOLCHAIN_CMAKE",
    "-DTARGET_BUILD_PLATFORM=windows",
    "-DPX_OUTPUT_ARCH=x64",
    "-DPHYSX_ROOT_DIR=$PHYSX_ROOT_CMAKE",
    "-DPXSHARED_PATH=$PXSHARED_PATH_CMAKE",
    "-DCMAKEMODULES_PATH=$CMAKE_MODULES_CMAKE",
    "-DPX_OUTPUT_LIB_DIR=$ABS_OUTPUT_DIR_CMAKE",
    "-DPX_OUTPUT_BIN_DIR=$ABS_OUTPUT_DIR_CMAKE",
    "-DPX_GENERATE_STATIC_LIBRARIES=ON",
    "-DPX_SIMD=0",
    "-DCMAKE_CXX_FLAGS=/D_DEBUG /W0"
)

& cmake $cmakeArgs

if ($LASTEXITCODE -ne 0) {
    throw "CMake configuration failed"
}

# -------------------------------------- 
# Build PhysX
# -------------------------------------- 
Write-Host "`n--- Building PhysX (Debug) ---" -ForegroundColor Cyan

& cmake --build "$PHYSX_BUILD_CMAKE" --config Debug

if ($LASTEXITCODE -ne 0) {
    throw "Build failed"
}

Write-Host "`n=== PhysX build completed successfully ===" -ForegroundColor Green

# -------------------------------------- 
# Summary
# -------------------------------------- 
Write-Host "`n--- Summary ---" -ForegroundColor Cyan
Write-Host "vcpkg configured" -ForegroundColor Green

if ($isManifestOnly) {
    Write-Host "vcpkg.json manifest created" -ForegroundColor Green
}

Write-Host "PhysX built successfully" -ForegroundColor Green