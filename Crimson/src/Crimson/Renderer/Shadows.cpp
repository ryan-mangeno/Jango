#include "cnpch.h"
#include "Crimson.h"
#include "Shadows.h"
#include "Platform/OpenGL/OpenGLShadows.h"

namespace Crimson
{
	Shadows::Shadows()
	{
	}
	Shadows::Shadows(float width, float height)
	{
	}
	Shadows::~Shadows()
	{
	}
	Ref<Shadows> Shadows::Create(float width, float height)
	{
		switch (RendererAPI::GetAPI())
		{
		case GraphicsAPI::None:
			return nullptr;
		case GraphicsAPI::OpenGL:
			return MakeRef<OpenGLShadows>(width,height);
		}
	}
	Ref<Shadows> Shadows::Create()
	{
		switch (RendererAPI::GetAPI())
		{
		case GraphicsAPI::None:
			return nullptr;
		case GraphicsAPI::OpenGL:
			return MakeRef<OpenGLShadows>(2048.f, 2048.f);
		}
	}
}