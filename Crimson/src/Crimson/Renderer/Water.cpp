#include "cnpch.h"

#include "Water.h"
#include "Platform/OpenGL/OpenGLWater.h"

namespace Crimson {


	Ref<Water> Water::Create(const glm::vec3& dims, const glm::vec4& water_color, const glm::vec2& screen_size)
	{
		switch (RendererAPI::GetAPI())
		{
			case GraphicsAPI::None:
				return nullptr;
			case GraphicsAPI::OpenGL:
				return MakeRef<OpenGLWater>( dims , water_color, screen_size );
			case GraphicsAPI::Metal:
				return nullptr;
			default:
				return nullptr;
		}
	}


}