# Copilot / AI Agent Instructions for Jango

Purpose: give an AI coding agent the essential, repo-specific knowledge to be immediately productive.

- **Quick context**: This repo is a game engine originally named *Crimson* (many paths still use `Crimson/`) now called Jango. Core library target is `Crimson` (static lib) and the primary executable is `Crimson_Editor`.
- **Top-level layout**: See [README.md](README.md) and [CMakeLists.txt](CMakeLists.txt) for high-level build flow. Vendor libs live under [Crimson/vendor](Crimson/vendor).

- **Quick start (Windows / MSVC)**:
  ```powershell
  mkdir build
  cd build
  cmake .. -G "Visual Studio 17 2022" -A x64
  cmake --build . --config Debug
  ```
  Alternatively run the provided generator: [scripts/WindowsGenerateProject.bat](scripts/WindowsGenerateProject.bat).

- **CMake behaviors to know**:
  - The top-level build is configured in [CMakeLists.txt](CMakeLists.txt). It will auto-init and switch the PhysX submodule to a pinned branch (`4.1`) if needed — expect Git operations during configure.
  - Output binaries are placed in `bin/${CMAKE_BUILD_TYPE}-${platform}-${arch}` (see `CMakeLists.txt` where `OUTPUT_DIR_NAME` is set).
  - Many third-party libraries are added via `add_subdirectory(Crimson/vendor/...)`. To add a vendor, follow that pattern and update `CRIMSON_VENDOR_INCLUDES` when needed.

- **Source organization & conventions**:
  - Core code: [Crimson/src](Crimson/src). The CMakeLists uses `file(GLOB_RECURSE ...)` for `Crimson/src/*.cpp` and `*.h`.
  - Platform-specific code: `Crimson/src/Platform/<Windows|Mac|...>` and the build excludes platform folders from core globs to avoid pollution.
  - Precompiled header: `Crimson/src/cnpch.h` is used via `target_precompile_headers`. New files should include the header consistently.
  - When adding a platform-specific implementation, place it under the appropriate `Platform/<OS>/` folder so CMake picks it up.

- **Key targets**:
  - `Crimson` — static library containing engine core.
  - `Crimson_Editor` — executable that links `Crimson` and is configured to run from the `Crimson_Editor` working directory (see property `VS_DEBUGGER_WORKING_DIRECTORY`).

- **Linking notes and Windows specifics**:
  - On Windows the CMake file composes exact PhysX lib paths and links several static libs (see `CMakeLists.txt` for the `PX_FULL_PATH` usage). If modifying PhysX, be careful to preserve the branch/paths logic.
  - Some vendor binaries are referenced directly (e.g. `Crimson/vendor/Curl/lib/libcurl_a_debug.lib`) — update paths or add copy/install rules if upgrading binaries.

- **Common patterns you should follow when modifying CMake**:
  - Use `add_subdirectory(Crimson/vendor/<name>)` for bundled libs rather than manually adding include/link flags.
  - Prefer adding source files into the `Crimson/src` tree; CMake's globbing will pick them up. Avoid changing the global glob rules unless necessary.
  - Honor the existing compile definitions/flags (e.g. `CN_PLATFORM_WINDOWS`, `YAML_CPP_STATIC_DEFINE`) so downstream code builds consistently.

- **Where to run & debugging**:
  - Built editor binary will be in `bin/<config>-<platform>-<arch>/Crimson_Editor.exe`. Run with working directory set to `Crimson_Editor` if you need assets/relative paths.
  - For native debugging use the generated Visual Studio solution under `build/` (e.g. open `CrimsonWorkspace.sln`).

- **Why things are structured this way (high-level rationale)**:
  - The project bundles many vendored libs for deterministic builds and easier CI. The CMake script automates vendor checkout and per-platform wiring to reduce manual setup.
  - The use of a single static `Crimson` library plus a small editor executable simplifies incremental builds and keeps the runtime binary thin.

- **Examples (copyable snippets)**:
  - Add a new vendor subdir to CMake (pattern):
    ```cmake
    add_subdirectory(Crimson/vendor/<yourlib>)
    list(APPEND CRIMSON_VENDOR_INCLUDES "Crimson/vendor/<yourlib>/include")
    ```

- **Hints for code changes**:
  - Keep names consistent with legacy `Crimson` naming; many paths/targets still use that identifier.
  - Respect platform stubs under `Crimson/src/Platform/Stubs` used to compile on other platforms.

If anything here is unclear or you want more examples (CI, packaging, or how to add a new vendor), tell me which area to expand and I'll update this file.
