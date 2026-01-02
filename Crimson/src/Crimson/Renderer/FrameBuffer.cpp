#include "cnpch.h"
#include "FrameBuffer.h"
#include "RendererAPI.h"
#include "Platform/OpenGL/OpenGLFrameBuffer.h"
#include "Platform/Metal/MetalFrameBuffer.h"

namespace Crimson {
    Ref<FrameBuffer> FrameBuffer::Create(const FrameBufferSpecification& spec)
    {
		switch (RendererAPI::GetAPI())
		{
		case GraphicsAPI::None:
			return nullptr;
		case GraphicsAPI::Metal:
			return MakeRef<MetalFrameBuffer>(spec);
		case GraphicsAPI::OpenGL:
			return MakeRef<OpenGLFrameBuffer>(spec);
		default:
			return nullptr;
		}
    }
}