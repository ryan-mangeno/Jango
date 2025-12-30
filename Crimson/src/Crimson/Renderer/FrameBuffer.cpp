#include "cnpch.h"
#include "FrameBuffer.h"
#include "RendererAPI.h"
#include "Platform/Opengl/OpenGLFrameBuffer.h"

namespace Crimson {
    Ref<FrameBuffer> FrameBuffer::Create(const FrameBufferSpecification& spec)
    {
		switch (RendererAPI::GetAPI())
		{
		case GraphicsAPI::None:
			return nullptr;
		case GraphicsAPI::OpenGL:
			return std::make_shared<OpenGLFrameBuffer>(spec);
		default:
			return nullptr;
		}
    }
}