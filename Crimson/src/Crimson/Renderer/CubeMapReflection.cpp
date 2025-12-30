#include "cnpch.h"
#include "CubeMapReflection.h"
#include "Platform/OpenGL/OpenGLCubeMapReflection.h"

namespace Crimson {
	CubeMapReflection::CubeMapReflection()
	{
	}
	CubeMapReflection::~CubeMapReflection()
	{
	}
	Ref<CubeMapReflection> CubeMapReflection::Create()
	{
		switch (RendererAPI::GetAPI())
		{
		case GraphicsAPI::None:
			return nullptr;
		case GraphicsAPI::OpenGL:
			return MakeRef<OpenGLCubeMapReflection>();
		}
	}
}