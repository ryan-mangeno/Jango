cmake_minimum_required(VERSION 3.16)
project(Glad C)

# ==========================================
# Target
# ==========================================
add_library(Glad STATIC
    "include/glad/glad.h"
    "include/KHR/khrplatform.h"
    "src/glad.c"
)

# ==========================================
# Include Directories
# ==========================================
# PUBLIC ensures that any project linking to Glad (like Crimson) 
# automatically gets "Crimson/vendor/Glad/include" added to its path.
target_include_directories(Glad PUBLIC "include")

# ==========================================
# Runtime & Settings
# ==========================================
#"staticruntime off" is the default CMake behavior on Windows 