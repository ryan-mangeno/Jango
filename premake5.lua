
-- may not need this, executing with gmake might be enough
--local useGCC = os.getenv("USE_GCC") or _ARGS[1] == "gcc"




workspace "Crimson"
    startproject "Crimson_Editor"
    architecture "x86_64"

    configurations
    {
        "Debug",
        "Release",
        "Dist"
    }

outputdir = "%{cfg.buildcfg}-%{cfg.system}-%{cfg.architecture}"

-- include dirs relative to solution dir
IncludeDir = {}
IncludeDir["GLFW"]     = "Crimson/vendor/GLFW/include"
IncludeDir["Glad"]     = "Crimson/vendor/Glad/include"
IncludeDir["ImGui"]    = "Crimson/vendor/imgui"
IncludeDir["Chroma"]   = "Crimson/vendor/Chroma"
IncludeDir["glm"]      = "Crimson/vendor/glm"
IncludeDir["Stb"]      = "Crimson/vendor/stb"
IncludeDir["entt"]     = "Crimson/vendor/entt"
IncludeDir["curl"]     = "Crimson/vendor/Curl/include"
IncludeDir["json"]     = "Crimson/vendor/jsoncpp"
IncludeDir["assimp"]   = "Crimson/vendor/assimp/include"
IncludeDir["Physx"]    = "Crimson/vendor/physx_x64-windows/include"
IncludeDir["yaml"]     = "Crimson/vendor/yaml-cpp/include"
IncludeDir["oidn"]     = "Crimson/vendor/oidn/include"
IncludeDir["ImGuizmo"] = "Crimson/vendor/ImGuizmo"

group "Dependencies"
    include "Crimson/vendor/GLFW"
    include "Crimson/vendor/imgui"
    include "Crimson/vendor/Glad"
    include "Crimson/vendor/Chroma"
    include "Crimson/vendor/yaml-cpp"
group ""

project "Crimson"
    location "Crimson"    
    kind "StaticLib"
    language "C++"
    cppdialect "C++17"
    staticruntime "off"

    targetdir ("bin/" .. outputdir .. "/%{prj.name}")
    objdir ("bin-int/" .. outputdir .. "/%{prj.name}")

    pchheader "cnpch.h"
    pchsource "Crimson/src/cnpch.cpp"

    files
    {
        "%{prj.name}/src/**.h",
        "%{prj.name}/src/**.cpp",
        -- vendor headers/sources
        "%{IncludeDir.curl}/**.h",
        "%{IncludeDir.curl}/**.c",
        "%{IncludeDir.json}/**.h",
        "%{IncludeDir.json}/**.cpp",
        "%{IncludeDir.entt}/**.hpp",
        "%{IncludeDir.assimp}/**.h",
        "%{IncludeDir.assimp}/**.cpp",
        "%{IncludeDir.Physx}/**.h",
        "%{IncludeDir.Physx}/**.hpp",
        "%{IncludeDir.oidn}/**.h",
        "%{IncludeDir.ImGuizmo}/ImGuizmo.h",
        "%{IncludeDir.ImGuizmo}/ImGuizmo.cpp",
        "%{IncludeDir.Stb}/**.h",
        "%{IncludeDir.Stb}/**.cpp",
        "%{IncludeDir.yaml}/**.h",
        "%{IncludeDir.yaml}/**.cpp",
    }

    includedirs
    {
        "Crimson/vendor/spdlog/include",
        "Crimson/src",
        "%{IncludeDir.GLFW}",
        "%{IncludeDir.Glad}",
        "%{IncludeDir.ImGui}",
        "%{IncludeDir.Chroma}",
        "%{IncludeDir.glm}",
        "%{IncludeDir.Stb}",
        "%{IncludeDir.curl}",
        "%{IncludeDir.json}",
        "%{IncludeDir.entt}",
        "%{IncludeDir.assimp}",
        "%{IncludeDir.Physx}",
        "%{IncludeDir.yaml}",
        "%{IncludeDir.oidn}",
        "%{IncludeDir.ImGuizmo}"
    }

    links
    {
        "GLFW",
        "Glad",
        "ImGui",
        "Chroma",
        "yaml-cpp",
    }

    defines 
    {
        "_CRT_SECURE_NO_WARNINGS",
        "PX_PHYSX_STATIC_LIB",
        "YAML_CPP_STATIC_DEFINE"
    }

    filter "system:windows"
        systemversion "latest"
        buildoptions { "/utf-8" }
        links
        {
            "opengl32.lib",
            "Normaliz.lib",
            "Ws2_32.lib",
            "Wldap32.lib",
            "Crypt32.lib",
            "advapi32.lib",
            "Crimson/vendor/Curl/lib/libcurl_a_debug.lib",
            "Crimson/vendor/assimp/lib/x64/assimp-vc143-mt.lib",
            "Crimson/vendor/physx_x64-windows/lib/**.lib",
            "Crimson/vendor/oidn/lib/OpenImageDenoise.lib",
            "Crimson/vendor/oidn/lib/OpenImageDenoise_core.lib",
        }
        defines { "CN_PLATFORM_WINDOWS", "CN_BUILD_DLL", "GLFW_INCLUDE_NONE" }





project "Sandbox"
	location "Sandbox"
	kind "ConsoleApp"
	language "C++"
	cppdialect "C++17"
	staticruntime "off"

	targetdir ("bin/" .. outputdir .. "/%{prj.name}")
	objdir ("bin-int/" .. outputdir .. "/%{prj.name}")

	files
    {
        "%{prj.name}/src/**.h",
        "%{prj.name}/src/**.cpp",
		"%{prj.name}/Assets/**.png",
        "%{prj.name}/vendor/glm/glm",
    }



	includedirs
	{
		"Crimson/vendor/spdlog/include",
		"Crimson/src",
		"Crimson/vendor",

		"%{IncludeDir.Chroma}",
		"%{IncludeDir.ImGui}",
		"%{IncludeDir.glm}",
		"%{IncludeDir.entt}",
		"%{IncludeDir.curl}",
		"%{IncludeDir.json}",
		"%{IncludeDir.ImGuizmo}",
		"%{IncludeDir.yaml}",
	}

	links
	{
		"Crimson",
	}

	filter "system:windows"
		systemversion "latest"

		defines
		{
			"CN_PLATFORM_WINDOWS"
		}


	filter "configurations:Debug"
		warnings "off"
		defines {"CN_DEBUG", "CN_ENABLE_ASSERTS"}
		runtime "Debug"
		symbols "on"

	filter "configurations:Release"
		defines "CN_RELEASE"
		runtime "Release"
		optimize "on"

	filter "configurations:Dist"
		defines "CN_DIST"
		buildoptions "Release"
		optimize "on"


project "Crimson_Editor"

	location "Crimson_Editor"
	kind "ConsoleApp"
	language "C++"
	cppdialect "C++17"
	staticruntime "off"

	targetdir ("bin/" .. outputdir .. "/%{prj.name}")
	objdir ("bin-int/" .. outputdir .. "/%{prj.name}")

	files
    {
        "%{prj.name}/src/**.h",
        "%{prj.name}/src/**.cpp",
		"%{prj.name}/Assets/**.png",
	}



	includedirs
	{
		"Crimson/vendor/spdlog/include",
		"Crimson/src",
		"Crimson/vendor",

		"%{IncludeDir.Chroma}",
		"%{IncludeDir.ImGui}",
		"%{IncludeDir.glm}",
		"%{IncludeDir.entt}",
		"%{IncludeDir.curl}",
		"%{IncludeDir.json}",
		"%{IncludeDir.Physx}",
		"%{IncludeDir.ImGuizmo}",
		"%{IncludeDir.yaml}",
	}

	postbuildcommands
	{
		'{COPY} "%{wks.location}/Crimson/vendor/assimp/dll/*.dll" "%{cfg.targetdir}/"',
		'{COPY} "%{wks.location}/Crimson/vendor/physx_x64-windows/dll/*.dll" "%{cfg.targetdir}/"'
	}

	links
	{
		"Crimson"
	}

	filter "system:windows"
		systemversion "latest"

		defines
		{
			"CN_PLATFORM_WINDOWS"
		}


	filter "configurations:Debug"
		warnings "off"
		defines {"CN_DEBUG", "CN_ENABLE_ASSERTS"}
		runtime "Debug"
		symbols "on"

	filter "configurations:Release"
		defines "CN_RELEASE"
		runtime "Release"
		optimize "on"

	filter "configurations:Dist"
		defines "CN_DIST"
		runtime "Release"
		optimize "on"

