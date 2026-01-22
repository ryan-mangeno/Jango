# WindowsGenerateCrimsonWorkspace.ps1
$ErrorActionPreference = "Stop"

$SCRIPT_DIR = Split-Path -Parent $MyInvocation.MyCommand.Path
$PROJECT_ROOT = Split-Path -Parent $SCRIPT_DIR
$BUILD_DIR = Join-Path $PROJECT_ROOT "build"

Write-Host "--- Generating CrimsonWorkspace Visual Studio Solution ---"
Write-Host "Project Root: $PROJECT_ROOT"
Write-Host "Build Dir: $BUILD_DIR"

if (-not (Test-Path $BUILD_DIR)) {
    New-Item -ItemType Directory -Path $BUILD_DIR | Out-Null
}

# Generate the solution for your project
cmake -S "$PROJECT_ROOT" -B "$BUILD_DIR" -G "Visual Studio 17 2022" -A x64

Write-Host "--- CrimsonWorkspace project generation completed ---"
