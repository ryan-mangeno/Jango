cd ..
update_module() {
    DIR=$1
    if [ -d "$DIR" ]; then
        echo "------------------------------------------------"
        echo "Processing $DIR..."
        cd "$DIR"
        
        # 1. Ensure we are on a branch (try main, then master, else create 'cmake-migration')
        git checkout main 2>/dev/null || git checkout master 2>/dev/null || git checkout -b cmake-migration
        
        # 2. Add and Commit
        git add .
        git commit -m "Add CMake build support"
        
        # 3. Push (pushing HEAD ensures it goes to whatever branch we found)
        git push origin HEAD
        
        # Return to root
        cd - > /dev/null
    else
        echo "Skipping $DIR (Directory not found)"
    fi
}

update_module "Crimson/vendor/Chroma"
update_module "Crimson/vendor/GLFW"
update_module "Crimson/vendor/imgui"
update_module "Crimson/vendor/yaml-cpp"
update_module "Crimson/vendor/Glad"
update_module "Crimson/vendor/ImGuizmo"

echo "------------------------------------------------"
echo "Updating Jango Root..."
git add .
git commit -m "Update submodules with CMakeLists"
git push origin main
echo "Done!"
