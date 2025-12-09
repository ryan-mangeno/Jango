# Ensure we are in the root of the repo
cd "$(git rev-parse --show-toplevel)"

# Function to update a single submodule with SSH fix
update_module() {
    DIR=$1
    if [ -d "$DIR" ]; then
        echo "------------------------------------------------"
        echo "Processing $DIR..."
        cd "$DIR"

        # --- AUTO-FIX: Switch HTTPS to SSH for ryan-mangeno repos ---
        CURRENT_URL=$(git remote get-url origin)
        if [[ "$CURRENT_URL" == https://github.com/ryan-mangeno/* ]]; then
            # Convert https://github.com/ryan-mangeno/XYZ.git -> git@github.com:ryan-mangeno/XYZ.git
            NEW_URL=${CURRENT_URL/https:\/\/github.com\/ryan-mangeno\//git@github.com:ryan-mangeno/}
            git remote set-url origin "$NEW_URL"
            echo "✅ Auto-switched remote to SSH: $NEW_URL"
        fi
        
        git checkout main 2>/dev/null || git checkout master 2>/dev/null || 

        if [[ -n $(git status --porcelain) ]]; then
            git add .
            git commit -m "Add CMake build support"
            echo "✅ Changes committed."
        else
            echo "⚡ No changes to commit in this module."
        git push origin head
        fi

        # Return to root
        cd - > /dev/null
    else
        echo "Skipping $DIR (Directory not found)"
    fi
}

# --- Run updates for all submodules ---
update_module "Crimson/vendor/Chroma"
update_module "Crimson/vendor/GLFW"
update_module "Crimson/vendor/imgui"
update_module "Crimson/vendor/yaml-cpp"
update_module "Crimson/vendor/Glad"
update_module "Crimson/vendor/ImGuizmo"

# --- Update the Main Root Repo ---
echo "------------------------------------------------"
echo "Updating Jango Root..."
git add .
git commit -m "Update submodules with CMakeLists"
git push origin main
echo "🎉 Done!"
