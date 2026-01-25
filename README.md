# Jango Engine

https://github.com/user-attachments/assets/f6f3b5bd-5687-4843-b6ec-6f0be10e0b51

## 📢 Announcement

I'm excited to announce a new game engine I will begin developing ! After careful consideration, I've decided to focus on Vulkan rather than pursuing full Metal support. 

> **Important:** The `windows-dev` branch currently provides out-of-the-box Windows support. If you'd like to fork this project and continue Metal support, please feel free! Reach out if you have questions about the architecture, event system, stub generation, or layered design.

---

## 🚀 Features (Current)

- **Cross-Platform Support**: Windows supported, macOS in progress
- **Spdlog**: Logging and debug tracing
- **ImGui**: Runtime testing UI
- **GLFW**: Window creation, contexts, input handling, and callbacks
- **Glad**: OpenGL function loading
- **Math Library**: Custom math library [Chroma](https://github.com/ryan-mangeno/Chroma) (migrating from GLM)
- **PhysX**: Physics library with optional NVIDIA GPU acceleration
- **yaml-cpp**: Configuration files and asset management
- **Assimp**: Model loading
- **ImGuizmo**: Object manipulation UI
- **EnTT**: Entity management system

### What's Being Worked On

- Full 3D Renderer
- 2D Renderer
- Physics Libraries Integration
- Multiplayer Networking Support (planned)

> **Note:** Some files may still reference the old engine name (**Crimson**). This will be updated as development continues.

![demobonnie](https://github.com/user-attachments/assets/af94219a-d3e7-4e6a-a7ab-1f6dcc44b066)
![demoo3](https://github.com/user-attachments/assets/2a36ba50-847e-4a23-84b6-29af4efa2b2f)

---

## 🛠️ Getting Started

### Prerequisites

- **C++ Compiler**: C++17 or higher (MSVC recommended for Windows)
- **CMake**: [Download here](https://cmake.org/download/)
- **Git**: For cloning and managing submodules
- **Visual Studio 2022**: For Windows development

---

### Installation & Build (Windows)

1. **Clone the Repository** (checkout the `windows-dev` branch):
```bash
   git clone --recursive -b windows-dev https://github.com/ryan-mangeno/Jango.git
   cd Jango
```

2. **Ensure Submodules are Initialized**:
```bash
   git submodule sync
   git submodule update --init --recursive --force
```

3. **Clean Previous Build Data** (if rebuilding):
```powershell
   if (Test-Path build) { Remove-Item -Recurse -Force build }
```

4. **Generate Visual Studio Solution**:
```powershell
   cmake -B build -G "Visual Studio 17 2022" -A x64 `
     -DASSIMP_BUILD_ASSIMP_VIEW=OFF `
     -DASSIMP_WARNINGS_AS_ERRORS=OFF `
     -DBUILD_DOCS=OFF
```

5. **Build the Editor**:
```powershell
   cmake --build build --config Debug --target Crimson_Editor
```

6. **Run the Editor**:
```powershell
   cd Crimson_Editor
   ..\bin\-windows-x86_64\Debug\Crimson_Editor.exe
```

---

## 💻 Contributing

Contributions are welcome! To contribute:

1. Fork the repository
2. Create a new branch for your feature or fix
3. Commit your changes with detailed messages
4. Submit a pull request

---

## 📦 Third-Party Libraries

All imported tools can be found in the `Crimson/vendor` directory. Special thanks to:
- GetIntoGameDev YouTube channel for relevant snippets and inspiration


---

Follow the repository for updates and stay tuned for new features!

