cmake_minimum_required(VERSION 3.16)
project(CrimsonWorkspace C CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# ==========================================
# Platform & Architecture Detection
# ==========================================
if(WIN32)
    set(PLATFORM_NAME "windows")
elseif(APPLE)
    set(PLATFORM_NAME "mac")
else()
    set(PLATFORM_NAME "linux")
endif()

# Detect Architecture (x86_64 vs arm64)
if(CMAKE_SYSTEM_PROCESSOR MATCHES "arm64")
    set(ARCH_NAME "arm64")
else()
    set(ARCH_NAME "x86_64")
endif()

# Set Output Directories
set(OUTPUT_DIR_NAME "${CMAKE_BUILD_TYPE}-${PLATFORM_NAME}-${ARCH_NAME}")
set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY ${CMAKE_SOURCE_DIR}/bin/${OUTPUT_DIR_NAME})
set(CMAKE_LIBRARY_OUTPUT_DIRECTORY ${CMAKE_SOURCE_DIR}/bin/${OUTPUT_DIR_NAME})
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_SOURCE_DIR}/bin/${OUTPUT_DIR_NAME})

# Custom "Dist" configuration
set(CMAKE_CONFIGURATION_TYPES "Debug;Release;Dist" CACHE STRING "" FORCE)
set(CMAKE_CXX_FLAGS_DIST "${CMAKE_CXX_FLAGS_RELEASE}" CACHE STRING "" FORCE)
set(CMAKE_EXE_LINKER_FLAGS_DIST "${CMAKE_EXE_LINKER_FLAGS_RELEASE}" CACHE STRING "" FORCE)

# ==========================================
# Dependencies
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

# Define Include Paths
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
set(INC_PHYSX "Crimson/vendor/physx_x64-windows/include") # need to seperate for mac
set(INC_YAML "Crimson/vendor/yaml-cpp/include")
set(INC_OIDN "Crimson/vendor/oidn/include")
set(INC_IMGUIZMO "Crimson/vendor/ImGuizmo")

# Gather Sources
file(GLOB_RECURSE CRIMSON_SRC 
    "Crimson/src/*.h"
    "Crimson/src/*.cpp"
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

# Include Directories
target_include_directories(Crimson PUBLIC
    "Crimson/vendor/spdlog/include"
    "Crimson/src"
    ${INC_GLFW} ${INC_GLAD} ${INC_IMGUI} ${INC_CHROMA}
    ${INC_GLM} ${INC_STB} ${INC_CURL} ${INC_JSON}
    ${INC_ENTT} ${INC_ASSIMP} ${INC_PHYSX} ${INC_YAML}
    ${INC_OIDN} ${INC_IMGUIZMO}
)

# Common Defines
target_compile_definitions(Crimson PUBLIC
    PX_PHYSX_STATIC_LIB
    YAML_CPP_STATIC_DEFINE
)

# Platform Specifics: Libraries & Defines

if(WIN32)
    # --- WINDOWS SETUP ---
    target_compile_definitions(Crimson PUBLIC CN_PLATFORM_WINDOWS CN_BUILD_DLL GLFW_INCLUDE_NONE _CRT_SECURE_NO_WARNINGS)
    target_compile_options(Crimson PRIVATE "/utf-8")
    
    # Windows System Libs
    target_link_libraries(Crimson PRIVATE
        opengl32.lib Normaliz.lib Ws2_32.lib Wldap32.lib Crypt32.lib advapi32.lib
    )

    # Vendor Libs (Windows)
    file(GLOB PHYSX_LIBS "Crimson/vendor/physx_x64-windows/lib/*.lib")
    target_link_libraries(Crimson PRIVATE
        "${CMAKE_SOURCE_DIR}/Crimson/vendor/Curl/lib/libcurl_a_debug.lib"
        "${CMAKE_SOURCE_DIR}/Crimson/vendor/assimp/lib/x64/assimp-vc143-mt.lib"
        "${CMAKE_SOURCE_DIR}/Crimson/vendor/oidn/lib/OpenImageDenoise.lib"
        "${CMAKE_SOURCE_DIR}/Crimson/vendor/oidn/lib/OpenImageDenoise_core.lib"
        ${PHYSX_LIBS}
    )

elseif(APPLE)
    target_compile_definitions(Crimson PUBLIC CN_PLATFORM_MACOS GLFW_INCLUDE_NONE)
    
    find_library(COCOA_LIB Cocoa)
    find_library(IOKIT_LIB IOKit)
    find_library(COREVIDEO_LIB CoreVideo)
    find_library(OPENGL_LIB OpenGL)
    
    # common Homebrew paths (/opt/homebrew for M1/M2, /usr/local for Intel)
    find_path(ASSIMP_INCLUDE_DIR assimp/Importer.hpp PATHS /opt/homebrew/include /usr/local/include REQUIRED)
    find_library(ASSIMP_LIB assimp PATHS /opt/homebrew/lib /usr/local/lib REQUIRED)

    message(STATUS "Found Mac Assimp Lib: ${ASSIMP_LIB}")
    message(STATUS "Found Mac Assimp Headers: ${ASSIMP_INCLUDE_DIR}")

    target_include_directories(Crimson PUBLIC ${ASSIMP_INCLUDE_DIR})
    
    target_link_libraries(Crimson PRIVATE 
        ${COCOA_LIB} ${IOKIT_LIB} ${COREVIDEO_LIB} ${OPENGL_LIB}
        ${ASSIMP_LIB} # Link the .dylib found by brew
    )

    # Vendor Libs (Mac)
    # WARNING: You must have Mac compatible .a or .dylib files for these libraries.
    # If you installed these via Homebrew (e.g. brew install assimp), use find_package/find_library instead.
    
    # Example approach: finding local libraries in a 'mac' folder
    # You need to manually ensure these files exist or adjust paths.
    
    # CUrl (Mac often has curl built-in, but if you use vendor):
    #target_link_libraries(Crimson PRIVATE curl) 
 
    # Assimp (Update path to your mac lib)
    #target_link_libraries(Crimson PRIVATE "${CMAKE_SOURCE_DIR}/Crimson/vendor/assimp/lib/mac/libassimp.dylib")

    # PhysX (Mac support exists but is rare in pre-compiled. If missing, remove temporarily)
    # target_link_libraries(Crimson PRIVATE "${CMAKE_SOURCE_DIR}/Crimson/vendor/PhysX/mac/libPhysX.a")

    # OIDN
    # target_link_libraries(Crimson PRIVATE "${CMAKE_SOURCE_DIR}/Crimson/vendor/oidn/lib/mac/libOpenImageDenoise.dylib")

endif()

# Linked CMake Targets
target_link_libraries(Crimson PUBLIC GLFW Glad ImGui Chroma yaml-cpp)


# ==========================================
# sandbox disabled for now
# ==========================================
#add_executable(Sandbox)

#file(GLOB_RECURSE SANDBOX_SRC "Sandbox/src/*.h" "Sandbox/src/*.cpp" "Sandbox/vendor/glm/glm")
#target_sources(Sandbox PRIVATE ${SANDBOX_SRC})

#target_include_directories(Sandbox PRIVATE
#    "Crimson/vendor/spdlog/include"
#    "Crimson/src" "Crimson/vendor"
#    ${INC_CHROMA} ${INC_IMGUI} ${INC_GLM} ${INC_ENTT}
#    ${INC_CURL} ${INC_JSON} ${INC_IMGUIZMO} ${INC_YAML}
#)
#target_link_libraries(Sandbox PRIVATE Crimson)

#if(WIN32)
#    target_compile_definitions(Sandbox PRIVATE CN_PLATFORM_WINDOWS)
#elseif(APPLE)
#    target_compile_definitions(Sandbox PRIVATE CN_PLATFORM_MACOS)
#endif()

#target_compile_definitions(Sandbox PRIVATE
#    $<$<CONFIG:Debug>:CN_DEBUG CN_ENABLE_ASSERTS>
#    $<$<CONFIG:Release>:CN_RELEASE>
#    $<$<CONFIG:Dist>:CN_DIST>
#)

# ==========================================
# Project: Crimson_Editor
# ==========================================
add_executable(Crimson_Editor)

file(GLOB_RECURSE EDITOR_SRC "Crimson_Editor/src/*.h" "Crimson_Editor/src/*.cpp")
target_sources(Crimson_Editor PRIVATE ${EDITOR_SRC})

target_include_directories(Crimson_Editor PRIVATE
    "Crimson/vendor/spdlog/include"
    "Crimson/src" "Crimson/vendor"
    ${INC_CHROMA} ${INC_IMGUI} ${INC_GLM} ${INC_ENTT}
    ${INC_CURL} ${INC_JSON} ${INC_PHYSX} ${INC_IMGUIZMO} ${INC_YAML}
)

target_link_libraries(Crimson_Editor PRIVATE Crimson)

if(WIN32)
    target_compile_definitions(Crimson_Editor PRIVATE CN_PLATFORM_WINDOWS)
elseif(APPLE)
    target_compile_definitions(Crimson_Editor PRIVATE CN_PLATFORM_MACOS)
endif()

target_compile_definitions(Crimson_Editor PRIVATE
    $<$<CONFIG:Debug>:CN_DEBUG CN_ENABLE_ASSERTS>
    $<$<CONFIG:Release>:CN_RELEASE>
    $<$<CONFIG:Dist>:CN_DIST>
)

# ==========================================
# Post Build: Copy Binaries
# ==========================================
if(WIN32)
    add_custom_command(TARGET Crimson_Editor POST_BUILD
        COMMAND ${CMAKE_COMMAND} -E copy_directory
        "${CMAKE_SOURCE_DIR}/Crimson/vendor/assimp/dll/"
        "$<TARGET_FILE_DIR:Crimson_Editor>/"
        COMMAND ${CMAKE_COMMAND} -E copy_directory
        "${CMAKE_SOURCE_DIR}/Crimson/vendor/physx_x64-windows/dll/"
        "$<TARGET_FILE_DIR:Crimson_Editor>/"
        COMMENT "Copying Vendor DLLs to Output Directory..."
    )
elseif(APPLE)
    # On Mac, we typically need to copy .dylibs if they aren't installed in system paths.
    # Adjust "lib/mac" to wherever you actually store your Mac dylibs.
    add_custom_command(TARGET Crimson_Editor POST_BUILD
        COMMAND ${CMAKE_COMMAND} -E copy_if_different
        "${CMAKE_SOURCE_DIR}/Crimson/vendor/assimp/lib/mac/libassimp.dylib"
        "$<TARGET_FILE_DIR:Crimson_Editor>/"
        COMMENT "Copying Mac dylibs..."
    )
endif()