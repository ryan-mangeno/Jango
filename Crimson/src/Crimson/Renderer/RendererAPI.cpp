#include "cnpch.h"
#include "RendererAPI.h"


namespace Crimson {

#ifdef CN_PLATFORM_WINDOWS
		GraphicsAPI RendererAPI::m_API = GraphicsAPI::OpenGL;
#elif CN_PLATFORM_MACOS
		GraphicsAPI RendererAPI::m_API = GraphicsAPI::Metal;
#endif

}
