#include "cnpch.h"
#include "RenderCommand.h"


#include "Platform/OpenGL/OpenGLRendererAPI.h"

namespace Crimson {

	Scope<RendererAPI> RenderCommand::s_RendererAPI =  MakeScope<OpenGLRendererAPI>();
	

	Ref<RendererAPI> RenderCommand::GetRendererAPI()
	{
		switch (RendererAPI::GetAPI()) 
		{
			case GraphicsAPI::None:   return nullptr;
			case GraphicsAPI::OpenGL: return std::make_shared<OpenGLRendererAPI>();
			
			default:                  
				CN_CORE_ERROR("No valid Graphics api");
				return nullptr;
		}
	}
}
