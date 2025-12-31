#include "cnpch.h"
#include "Crimson/Renderer/SSAO.h"
#include "Crimson/Renderer/RendererAPI.h"

// Include Platform Specific Headers
#include "Platform/OpenGL/OpenGLSSAO.h"
#include "Platform/Metal/MetalSSAO.h"

namespace Crimson {

    Ref<SSAO> SSAO::Create(int width, int height)
    {
        switch (RendererAPI::GetAPI())
        {
        case GraphicsAPI::None:    return nullptr;
        case GraphicsAPI::OpenGL:  return MakeRef<OpenGLSSAO>(width, height);
        case GraphicsAPI::Metal:   return MakeRef<MetalSSAO>(width, height);
        }
        
        CN_CORE_ASSERT(false, "Unknown RendererAPI!");
        return nullptr;
    }
}