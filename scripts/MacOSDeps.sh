echo "Checking for Homebrew..."
if ! command -v brew &> /dev/null; then
    echo "Error: Homebrew is required for dependency management."
    echo "Please install Homebrew from https://brew.sh/"
    exit 1
fi

REQUIRED_DEPS=("assimp" "cmake")
for dep in "${REQUIRED_DEPS[@]}"; do
    if ! brew list "$dep" &>/dev/null; then
        echo "Installing required dependency: $dep..."
        brew install "$dep"
    else
        echo "$dep is already installed."
    fi
done

VENDOR_PATH=$"./Crimson/vendor"

if [ -d "${VENDOR_PATH}/Nvidia-PhysX" ]; then 
    echo "Unpacking PhysX ..."
    cd "${VENDOR_PATH}/Nvidia-PhysX/physx/"
    ./generate_projects.sh mac64
    popd
else
    echo "Error unpacking PhysX, check if submodules have been cloned"
    exit 1
fi


echo "--- Setup Complete ---"
echo "Next Step: generate project files using MacOSGenerateProject.sh in the scripts folder"