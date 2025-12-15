# ensure we are in the root of the repo
cd "$(git rev-parse --show-toplevel)"

update_module() {
    DIR=$1
    if [ -d "$DIR" ]; then
        echo "------------------------------------------------"
        echo "Processing $DIR..."
        cd "$DIR"

        CURRENT_URL=$(git remote get-url origin)
        if [[ "$CURRENT_URL" == https://github.com/ryan-mangeno/* ]]; then
            NEW_URL=${CURRENT_URL/https:\/\/github.com\/ryan-mangeno\//git@github.com:ryan-mangeno/}
            git remote set-url origin "$NEW_URL"
            echo "Auto-switched remote to SSH: $NEW_URL"
        fi

        git fetch --all --quiet
        

        if [[ "$DIR" == *"imgui"* ]]; then
            # imgui must use docking
            git checkout docking 2>/dev/null || git checkout -b docking origin/docking
        else
            # Others use main or master
            git checkout main 2>/dev/null || git checkout master 2>/dev/null || git checkout -b cmake-migration
        fi
        if [[ -n $(git status --porcelain) ]]; then
            git add .
            git commit -m "Add CMake build support"
            echo "Changes committed."
        else
            echo "⚡ No changes to commit in this module."
        fi
        git push origin head
        # return to root
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

echo "------------------------------------------------"
echo "Updating Jango Root..."
git add .
git commit -m "Update submodules with CMakeLists"
git push origin main
echo "🎉 Done!"
