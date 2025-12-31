#include "cnpch.h"

#include "RenderCommand.h"
#include "Platform/OpenGL/OpenGLRendererAPI.h"
#include "Platform/Metal/MetalRendererAPI.h"

namespace Crimson {

#if defined(CN_PLATFORM_WINDOWS)
	Scope<RendererAPI> RenderCommand::s_RendererAPI =  MakeScope<OpenGLRendererAPI>();
#elif defined(CN_PLATFORM_MACOS)
	Scope<RendererAPI> RenderCommand::s_RendererAPI =  MakeScope<MetalRendererAPI>();
#endif


	Ref<RendererAPI> RenderCommand::GetRendererAPI()
	{
		switch (RendererAPI::GetAPI()) 
		{
			case GraphicsAPI::None:   return nullptr;
			case GraphicsAPI::Metal:  return MakeRef<MetalRendererAPI>();
			case GraphicsAPI::OpenGL: return MakeRef<OpenGLRendererAPI>();
			
			default:                  
				CN_CORE_ERROR("No valid Graphics api");
				return nullptr;
		}
	}
}
