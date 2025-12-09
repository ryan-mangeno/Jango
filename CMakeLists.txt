cmake_minimum_required(VERSION 3.16)
project(CrimsonWorkspace C CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Set Output Directories to mimic Premake's bin/ structure roughly
set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY ${CMAKE_SOURCE_DIR}/bin/${CMAKE_BUILD_TYPE}-windows-x86_64)
set(CMAKE_LIBRARY_OUTPUT_DIRECTORY ${CMAKE_SOURCE_DIR}/bin/${CMAKE_BUILD_TYPE}-windows-x86_64)
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_SOURCE_DIR}/bin/${CMAKE_BUILD_TYPE}-windows-x86_64)

# Define a custom "Dist" configuration type if needed, mapping it to Release
set(CMAKE_CONFIGURATION_TYPES "Debug;Release;Dist" CACHE STRING "" FORCE)
set(CMAKE_CXX_FLAGS_DIST "${CMAKE_CXX_FLAGS_RELEASE}" CACHE STRING "" FORCE)
set(CMAKE_EXE_LINKER_FLAGS_DIST "${CMAKE_EXE_LINKER_FLAGS_RELEASE}" CACHE STRING "" FORCE)

# ==========================================
# Dependencies (add_subdirectory)
# Assumes these folders have CMakeLists.txt
# ==========================================
add_subdirectory(Crimson/vendor/GLFW)
add_subdirectory(Crimson/vendor/imgui)
add_subdirectory(Crimson/vendor/Glad)
add_subdirectory(Crimson/vendor/Chroma)
add_subdirectory(Crimson/vendor/yaml-cpp)

# ==========================================
# Project: Crimson (Static Library)
# ==========================================
add_library(Crimson STATIC)

# Define Include Paths Variables for readability
set(INC_GLFW "Crimson/vendor/GLFW/include")
set(INC_GLAD "Crimson/vendor/Glad/include")
set(INC_IMGUI "Crimson/vendor/imgui")
set(INC_CHROMA "Crimson/vendor/Chroma")
set(INC_GLM "Crimson/vendor/glm")
set(INC_STB "Crimson/vendor/stb")
set(INC_ENTT "Crimson/vendor/entt")
set(INC_CURL "Crimson/vendor/Curl/include")
set(INC_JSON "Crimson/vendor/jsoncpp")
set(INC_ASSIMP "Crimson/vendor/assimp/include")
set(INC_PHYSX "Crimson/vendor/physx_x64-windows/include")
set(INC_YAML "Crimson/vendor/yaml-cpp/include")
set(INC_OIDN "Crimson/vendor/oidn/include")
set(INC_IMGUIZMO "Crimson/vendor/ImGuizmo")

# Gather Sources (Replicating Premake wildcards)
file(GLOB_RECURSE CRIMSON_SRC 
    "Crimson/src/*.h"
    "Crimson/src/*.cpp"
    # Vendor sources compiled directly into Crimson
    "${INC_CURL}/*.h" "${INC_CURL}/*.c"
    "${INC_JSON}/*.h" "${INC_JSON}/*.cpp"
    "${INC_ENTT}/*.hpp"
    "${INC_ASSIMP}/*.h" "${INC_ASSIMP}/*.cpp"
    "${INC_PHYSX}/*.h" "${INC_PHYSX}/*.hpp"
    "${INC_OIDN}/*.h"
    "${INC_IMGUIZMO}/ImGuizmo.h" "${INC_IMGUIZMO}/ImGuizmo.cpp"
    "${INC_STB}/*.h" "${INC_STB}/*.cpp"
    "${INC_YAML}/*.h" "${INC_YAML}/*.cpp"
)

target_sources(Crimson PRIVATE ${CRIMSON_SRC})

# Precompiled Header
target_precompile_headers(Crimson PRIVATE "Crimson/src/cnpch.h")
# Note: CMake handles the creation of the .cpp for PCH automatically usually, 
# but specific logic in cnpch.cpp, you might need to exclude it or include it specifically.

# Include Directories
target_include_directories(Crimson PUBLIC
    "Crimson/vendor/spdlog/include"
    "Crimson/src"
    ${INC_GLFW} ${INC_GLAD} ${INC_IMGUI} ${INC_CHROMA}
    ${INC_GLM} ${INC_STB} ${INC_CURL} ${INC_JSON}
    ${INC_ENTT} ${INC_ASSIMP} ${INC_PHYSX} ${INC_YAML}
    ${INC_OIDN} ${INC_IMGUIZMO}
)

# Defines
target_compile_definitions(Crimson PUBLIC
    _CRT_SECURE_NO_WARNINGS
    PX_PHYSX_STATIC_LIB
    YAML_CPP_STATIC_DEFINE
)

if(WIN32)
    target_compile_definitions(Crimson PUBLIC CN_PLATFORM_WINDOWS CN_BUILD_DLL GLFW_INCLUDE_NONE)
    target_compile_options(Crimson PRIVATE "/utf-8")
    
    # Windows System Libs
    target_link_libraries(Crimson PRIVATE
        opengl32.lib Normaliz.lib Ws2_32.lib Wldap32.lib Crypt32.lib advapi32.lib
    )

    # Precompiled Libs 
    file(GLOB PHYSX_LIBS "Crimson/vendor/physx_x64-windows/lib/*.lib")
    
    target_link_libraries(Crimson PRIVATE
        "${CMAKE_SOURCE_DIR}/Crimson/vendor/Curl/lib/libcurl_a_debug.lib"
        "${CMAKE_SOURCE_DIR}/Crimson/vendor/assimp/lib/x64/assimp-vc143-mt.lib"
        "${CMAKE_SOURCE_DIR}/Crimson/vendor/oidn/lib/OpenImageDenoise.lib"
        "${CMAKE_SOURCE_DIR}/Crimson/vendor/oidn/lib/OpenImageDenoise_core.lib"
        ${PHYSX_LIBS}
    )
endif()

# Dependencies linked via CMake targets
target_link_libraries(Crimson PUBLIC GLFW Glad ImGui Chroma yaml-cpp)


# ==========================================
# Project: Sandbox (Console App)
# ==========================================
add_executable(Sandbox)

file(GLOB_RECURSE SANDBOX_SRC 
    "Sandbox/src/*.h" "Sandbox/src/*.cpp"
    "Sandbox/vendor/glm/glm" 
)
target_sources(Sandbox PRIVATE ${SANDBOX_SRC})

target_include_directories(Sandbox PRIVATE
    "Crimson/vendor/spdlog/include"
    "Crimson/src"
    "Crimson/vendor"
    ${INC_CHROMA} ${INC_IMGUI} ${INC_GLM} ${INC_ENTT}
    ${INC_CURL} ${INC_JSON} ${INC_IMGUIZMO} ${INC_YAML}
)

target_link_libraries(Sandbox PRIVATE Crimson)

if(WIN32)
    target_compile_definitions(Sandbox PRIVATE CN_PLATFORM_WINDOWS)
endif()

# Configuration specific defines
target_compile_definitions(Sandbox PRIVATE
    $<$<CONFIG:Debug>:CN_DEBUG CN_ENABLE_ASSERTS>
    $<$<CONFIG:Release>:CN_RELEASE>
    $<$<CONFIG:Dist>:CN_DIST>
)


# ==========================================
# Project: Crimson_Editor (Console App)
# ==========================================
add_executable(Crimson_Editor)

file(GLOB_RECURSE EDITOR_SRC "Crimson_Editor/src/*.h" "Crimson_Editor/src/*.cpp")
target_sources(Crimson_Editor PRIVATE ${EDITOR_SRC})

target_include_directories(Crimson_Editor PRIVATE
    "Crimson/vendor/spdlog/include"
    "Crimson/src"
    "Crimson/vendor"
    ${INC_CHROMA} ${INC_IMGUI} ${INC_GLM} ${INC_ENTT}
    ${INC_CURL} ${INC_JSON} ${INC_PHYSX} ${INC_IMGUIZMO} ${INC_YAML}
)

target_link_libraries(Crimson_Editor PRIVATE Crimson)

if(WIN32)
    target_compile_definitions(Crimson_Editor PRIVATE CN_PLATFORM_WINDOWS)
endif()

target_compile_definitions(Crimson_Editor PRIVATE
    $<$<CONFIG:Debug>:CN_DEBUG CN_ENABLE_ASSERTS>
    $<$<CONFIG:Release>:CN_RELEASE>
    $<$<CONFIG:Dist>:CN_DIST>
)

# Post Build Commands (Copy DLLs)
add_custom_command(TARGET Crimson_Editor POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E copy_directory
    "${CMAKE_SOURCE_DIR}/Crimson/vendor/assimp/dll/"
    "$<TARGET_FILE_DIR:Crimson_Editor>/"
    COMMAND ${CMAKE_COMMAND} -E copy_directory
    "${CMAKE_SOURCE_DIR}/Crimson/vendor/physx_x64-windows/dll/"
    "$<TARGET_FILE_DIR:Crimson_Editor>/"
    COMMENT "Copying Vendor DLLs to Output Directory..."
)