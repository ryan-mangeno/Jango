#include "cnpch.h"
#include "Fog.h"
#include "Platform/OpenGL/OpenGLFog.h"

namespace Crimson
{
	Ref<Fog> Fog::Create(float density, float fogStart, float fogEnd, float fogTop, float fogBottom, glm::vec2 ScreenSize)
	{
		switch (RendererAPI::GetAPI())
		{
		case GraphicsAPI::None:
			return nullptr;
		case GraphicsAPI::Metal:
			return nullptr;
		case GraphicsAPI::OpenGL:
			return MakeRef<OpenGLFog>(density, fogStart, fogEnd, fogTop, fogBottom, ScreenSize);
		default:
			return nullptr;
		}
	}
}