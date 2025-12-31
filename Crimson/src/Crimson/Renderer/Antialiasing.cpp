#include "cnpch.h"
#include "Antialiasing.h"
#include "Platform/OpenGL/OpenGLAntialiasing.h"

#include <glm/glm.hpp>

namespace Crimson
{

	int Antialiasing::frameCount = 0;

	Antialiasing::Antialiasing()
	{
	}
	Antialiasing::~Antialiasing()
	{
	}

	Ref<Antialiasing> Antialiasing::Create(int width, int height)
	{
		CN_PROFILE_FUNCTION()

		switch (RendererAPI::GetAPI())
		{
		case GraphicsAPI::OpenGL:
			return MakeRef<OpenGLAntialiasing>(width,height);
		case GraphicsAPI::Metal:
			return nullptr;
		case GraphicsAPI::None:
			return nullptr;
		default:
			return MakeRef<OpenGLAntialiasing>(width,height);//default renderer is opengl
		}
	}
	glm::vec2 Antialiasing::GetJitterOffset()
	{

		auto halton = [](int base, int index)
		{
			float result = 0.;
			float f = 1.;
			while (index > 0)
			{
				f = f / float(base);
				result += f * float(index % base);
				index = index / base;
			}
			return result;
		};
		++frameCount;
		auto res = RenderCommand::GetViewportSize(); //get screen resolution
		glm::vec2 jitter = glm::vec2(halton(2, frameCount), halton(3, frameCount));
		jitter = ((jitter - 0.5f)/res) * 2.0f; //convert from -1 to +1
		//jitter /= res; //jitter in pixel level
		return jitter;
	}
}