cmake_minimum_required(VERSION 3.16)
project(CrimsonWorkspace C CXX)

if(APPLE)
    enable_language(OBJC OBJCXX)
endif()

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_OSX_DEPLOYMENT_TARGET "15.5")

if(WIN32)
    set(PLATFORM_NAME "windows")
    set(PHYSX_BRANCH "4.1")
elseif(APPLE)
    set(PLATFORM_NAME "mac")
    set(PHYSX_BRANCH "mac")
else()
    set(PLATFORM_NAME "linux")
endif()

# physx configuring, a little messy but it works for now
find_package(Git REQUIRED)
set(PHYSX_DIR "${CMAKE_SOURCE_DIR}/Crimson/vendor/PhysX")

if(NOT EXISTS "${PHYSX_DIR}/.git")
    message(STATUS "Initializing PhysX submodule...")
    execute_process(
        COMMAND ${GIT_EXECUTABLE} submodule update --init --recursive Crimson/vendor/PhysX
        WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}
    )
endif()

execute_process(
    COMMAND ${GIT_EXECUTABLE} -C "${PHYSX_DIR}" rev-parse --abbrev-ref HEAD
    OUTPUT_VARIABLE CURRENT_PX_BRANCH
    OUTPUT_STRIP_TRAILING_WHITESPACE
    ERROR_QUIET
)

if(NOT "${CURRENT_PX_BRANCH}" STREQUAL "${PHYSX_BRANCH}")
    message(STATUS "PhysX is on '${CURRENT_PX_BRANCH}'. Forcing switch to '${PHYSX_BRANCH}'...")

    execute_process(COMMAND ${GIT_EXECUTABLE} -C "${PHYSX_DIR}" fetch origin)

    execute_process(
        COMMAND ${GIT_EXECUTABLE} -C "${PHYSX_DIR}" checkout -f ${PHYSX_BRANCH}
        RESULT_VARIABLE GIT_RES
    )

    if(NOT GIT_RES EQUAL 0)
        message(FATAL_ERROR "Could not checkout PhysX branch: ${PX_BRANCH}")
    endif()
endif()



if(CMAKE_SYSTEM_PROCESSOR MATCHES "arm64")
    set(ARCH_NAME "arm64")
else()
    set(ARCH_NAME "x86_64")
endif()

set(OUTPUT_DIR_NAME "${CMAKE_BUILD_TYPE}-${PLATFORM_NAME}-${ARCH_NAME}")
set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY ${CMAKE_SOURCE_DIR}/bin/${OUTPUT_DIR_NAME})
set(CMAKE_LIBRARY_OUTPUT_DIRECTORY ${CMAKE_SOURCE_DIR}/bin/${OUTPUT_DIR_NAME})
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_SOURCE_DIR}/bin/${OUTPUT_DIR_NAME})

set(CMAKE_CONFIGURATION_TYPES "Debug;Release;Dist" CACHE STRING "" FORCE)
set(CMAKE_CXX_FLAGS_DIST "${CMAKE_CXX_FLAGS_RELEASE}" CACHE STRING "" FORCE)
set(CMAKE_EXE_LINKER_FLAGS_DIST "${CMAKE_EXE_LINKER_FLAGS_RELEASE}" CACHE STRING "" FORCE)

add_subdirectory(Crimson/vendor/GLFW)
add_subdirectory(Crimson/vendor/imgui)
add_subdirectory(Crimson/vendor/Glad)
add_subdirectory(Crimson/vendor/Chroma)
add_subdirectory(Crimson/vendor/yaml-cpp)
add_subdirectory(Crimson/vendor/PhysX) 

# Build Settings
set(ASSIMP_BUILD_ZLIB ON CACHE BOOL "" FORCE)       # Build internal Zlib
set(ASSIMP_BUILD_TESTS OFF CACHE BOOL "" FORCE)     # No Tests
set(ASSIMP_BUILD_ASSIMP_TOOLS OFF CACHE BOOL "" FORCE) # No Tools
set(ASSIMP_BUILD_SAMPLES OFF CACHE BOOL "" FORCE)   # No Samples
set(ASSIMP_BUILD_DOCS OFF CACHE BOOL "" FORCE)      # No Docs

add_subdirectory(Crimson/vendor/assimp)

set_target_properties(assimp PROPERTIES 
    OUTPUT_NAME "Assimp"
    DEBUG_POSTFIX ""      
    MinSizeRel_POSTFIX ""
    RelWithDebInfo_POSTFIX ""
)

# Disable the version suffixes (vc143, etc)
set(ASSIMP_INJECT_DEBUG_POSTFIX OFF CACHE BOOL "" FORCE)



# ---------------------------------------
# CRIMSON CORE LIB
# ---------------------------------------
add_library(Crimson STATIC)

set(CRIMSON_VENDOR_INCLUDES
    "Crimson/vendor"

    "Crimson/vendor/GLFW/include"
    "Crimson/vendor/Glad/include"
    "Crimson/vendor/imgui"
    "Crimson/vendor/Chroma"
    "Crimson/vendor/glm"
    "Crimson/vendor/stb"
    "Crimson/vendor/entt"
    "Crimson/vendor/Curl/include"
    "Crimson/vendor/jsoncpp"
    "Crimson/vendor/assimp/include"
    "Crimson/vendor/yaml-cpp/include"
    "Crimson/vendor/oidn/include"
    "Crimson/vendor/ImGuizmo"
    "Crimson/vendor/spdlog/include"
)


# Glob common core files
file(GLOB_RECURSE CRIMSON_CORE_SRC 
    "Crimson/src/*.h" "Crimson/src/*.cpp"
    "Crimson/vendor/Curl/include/*.h" "Crimson/vendor/Curl/include/*.c"
    "Crimson/vendor/jsoncpp/*.h" "Crimson/vendor/jsoncpp/*.cpp"
    "Crimson/vendor/ImGuizmo/ImGuizmo.h" "Crimson/vendor/ImGuizmo/ImGuizmo.cpp" 
    "Crimson/vendor/stb/*.cpp"
)

# Exclude Platform folders from Core Glob to avoid pollution
file(GLOB_RECURSE ALL_PLATFORM_SRC "Crimson/src/Platform/*")
list(REMOVE_ITEM CRIMSON_CORE_SRC ${ALL_PLATFORM_SRC})

# Platform Specific Sources & Stubs
if(WIN32)
    # Windows Sources
    file(GLOB_RECURSE PLATFORM_SRC 
        "Crimson/src/Platform/Windows/*.h" "Crimson/src/Platform/Windows/*.cpp"
        "Crimson/src/Platform/OpenGL/*.h"  "Crimson/src/Platform/OpenGL/*.cpp"
    )
    # Metal Stubs (since we are on Windows)
    file(GLOB_RECURSE PLATFORM_STUBS 
        "Crimson/src/Platform/Stubs/Metal/*.h" "Crimson/src/Platform/Stubs/Metal/*.cpp"
    )
elseif(APPLE)
    # Mac/Metal Sources
    file(GLOB_RECURSE PLATFORM_SRC 
        "Crimson/src/Platform/Mac/*.h" "Crimson/src/Platform/Mac/*.cpp" "Crimson/src/Platform/Mac/*.mm"
        "Crimson/src/Platform/Metal/*.h" "Crimson/src/Platform/Metal/*.cpp" "Crimson/src/Platform/Metal/*.mm"
    )
    # OpenGL Stubs (since we are on Mac)
    file(GLOB_RECURSE PLATFORM_STUBS 
        "Crimson/src/Platform/Stubs/OpenGL/*.h" "Crimson/src/Platform/Stubs/OpenGL/*.cpp"
    )

    # Obj-C++ Precompile Header Skip
    foreach(file ${PLATFORM_SRC})
        if(file MATCHES "\\.mm$")
            set_source_files_properties(${file} PROPERTIES SKIP_PRECOMPILE_HEADERS ON)
        endif()
    endforeach()
endif()

# Final Source List
target_sources(Crimson PRIVATE 
    ${CRIMSON_CORE_SRC} 
    ${PLATFORM_SRC} 
    ${PLATFORM_STUBS}
)

# Precompiled Headers
target_precompile_headers(Crimson PRIVATE
    "$<$<COMPILE_LANGUAGE:CXX>:Crimson/src/cnpch.h>"
    "$<$<COMPILE_LANGUAGE:OBJCXX>:Crimson/src/cnpch.h>"
)

# Includes & Defines
target_include_directories(Crimson PUBLIC "Crimson/src" ${CMAKE_SOURCE_DIR} ${CRIMSON_VENDOR_INCLUDES} "build/Crimson/vendor/assimp/include")

target_compile_definitions(Crimson PUBLIC
    YAML_CPP_STATIC_DEFINE
    $<$<CONFIG:Debug>:_DEBUG>
    $<$<CONFIG:Release>:NDEBUG>
    $<$<CONFIG:Dist>:NDEBUG>
)

# Linking
link_directories(${CMAKE_SOURCE_DIR}/bin/${OUTPUT_DIR_NAME})
target_link_libraries(Crimson PUBLIC GLFW Glad ImGui Chroma yaml-cpp Assimp PhysX)

if(WIN32)
    target_compile_definitions(Crimson PUBLIC CN_PLATFORM_WINDOWS CN_BUILD_DLL GLFW_INCLUDE_NONE _CRT_SECURE_NO_WARNINGS)
    target_compile_options(Crimson PRIVATE "/utf-8" "/wd4828")

    # Use Generator Expressions to handle the Debug/Release switch automatically
    set(PX_BASE_PATH "${PHYSX_DIR}/physx/bin/win.x86_64.vc142.md")
    set(PX_CONFIG_PATH "$<IF:$<CONFIG:Debug>,debug,release>")
    set(PX_FULL_PATH "${PX_BASE_PATH}/${PX_CONFIG_PATH}")

    target_link_libraries(Crimson PRIVATE
        opengl32.lib Normaliz.lib Ws2_32.lib Wldap32.lib Crypt32.lib advapi32.lib
        zlibstatic 
        "${PX_FULL_PATH}/PhysX_static_64.lib"
        "${PX_FULL_PATH}/PhysXCommon_static_64.lib"
        "${PX_FULL_PATH}/PhysXFoundation_static_64.lib"
        "${PX_FULL_PATH}/PhysXExtensions_static_64.lib"
        "${PX_FULL_PATH}/PhysXCooking_static_64.lib"
        "${PX_FULL_PATH}/PhysXPvdSDK_static_64.lib"
        
        "${CMAKE_SOURCE_DIR}/Crimson/vendor/Curl/lib/libcurl_a_debug.lib"
        "${CMAKE_SOURCE_DIR}/Crimson/vendor/oidn/lib/OpenImageDenoise.lib"
        "${CMAKE_SOURCE_DIR}/Crimson/vendor/oidn/lib/OpenImageDenoise_core.lib"
    )
elseif(APPLE)
    target_compile_definitions(Crimson PUBLIC CN_PLATFORM_MACOS GLFW_INCLUDE_NONE)
    target_compile_options(Crimson PRIVATE "-fobjc-arc")

    find_library(COCOA_LIB Cocoa)
    find_library(IOKIT_LIB IOKit)
    find_library(COREVIDEO_LIB CoreVideo)
    find_library(OPENGL_LIB OpenGL)
    find_library(QUARTZ_LIB QuartzCore)

    target_link_libraries(Crimson PRIVATE ${COCOA_LIB} ${IOKIT_LIB} ${COREVIDEO_LIB} ${OPENGL_LIB} ${QUARTZ_LIB})
endif()

# --- CRIMSON EDITOR SETUP ---
add_executable(Crimson_Editor)

file(GLOB_RECURSE EDITOR_SRC "Crimson_Editor/src/*.h" "Crimson_Editor/src/*.cpp")
target_sources(Crimson_Editor PRIVATE ${EDITOR_SRC})

# Linking (Inherits Includes/Defines from Crimson because it is PUBLIC)
target_link_libraries(Crimson_Editor PRIVATE Crimson)

# Platform Specifics for Editor
if(WIN32)
    target_compile_definitions(Crimson_Editor PRIVATE CN_PLATFORM_WINDOWS)
    set_target_properties(Crimson_Editor PROPERTIES LINK_FLAGS "/NODEFAULTLIB:LIBCMTD /NODEFAULTLIB:MSVCRT")
    
    if(MSVC)
        target_compile_options(Crimson_Editor PRIVATE "/utf-8" "/Zc:preprocessor" "/wd4828")
    endif()
elseif(APPLE)
    target_compile_definitions(Crimson_Editor PRIVATE CN_PLATFORM_MACOS)
endif()

target_compile_definitions(Crimson_Editor PRIVATE
    $<$<CONFIG:Debug>:CN_DEBUG CN_ENABLE_ASSERTS>
    $<$<CONFIG:Release>:CN_RELEASE>
    $<$<CONFIG:Dist>:CN_DIST>
)