#include "cnpch.h"
#include "Platform/OpenGL/OpenGLDeferredRenderer.h"
#include "Platform/Metal/MetalDeferredRenderer.h"
#include "DeferredRenderer.h"

namespace Crimson
{
	void DefferedRenderer::Init(int width, int height)
	{
		switch(RendererAPI::GetAPI()) 
		{
			case GraphicsAPI::OpenGL: 	OpenGLDeferredRenderer::Init(width,height); break;
			case GraphicsAPI::Metal:  	MetalDeferredRenderer::Init(width,height); 	break;
			case GraphicsAPI::None:
			default: 					CN_CORE_ERROR("Invalid Graphics API (Defferred Renderer Initialization Failed)");
		}
	}
	void DefferedRenderer::GenerateGBuffers(Scene* scene, bool withWater)
	{
		switch(RendererAPI::GetAPI()) 
		{
			case GraphicsAPI::OpenGL:	OpenGLDeferredRenderer::CreateBuffers(scene, withWater); break;
			case GraphicsAPI::Metal:	MetalDeferredRenderer::CreateBuffers(scene, withWater);  break;
			case GraphicsAPI::None:
			default: 					CN_CORE_ERROR("Invalid Graphics API (GBuffer Creation Failed)");
		}
	}
	void DefferedRenderer::DeferredRenderPass()
	{
		switch(RendererAPI::GetAPI()) 
		{
			case GraphicsAPI::OpenGL:	OpenGLDeferredRenderer::DeferredPass(); break;
			case GraphicsAPI::Metal:	MetalDeferredRenderer::DeferredPass(); break;
			case GraphicsAPI::None:
			default: 					CN_CORE_ERROR("Invalid Graphics API (Defferred Renderer Pass Failed)");
		}
	}
	Ref<Shader> DefferedRenderer::GetDeferredPassShader()
	{
		switch(RendererAPI::GetAPI()) 
		{
			case GraphicsAPI::OpenGL:	return OpenGLDeferredRenderer::GetDeferredShader();
			case GraphicsAPI::Metal:	return MetalDeferredRenderer::GetDeferredShader();
			case GraphicsAPI::None:
			default: 					CN_CORE_ERROR("Invalid Graphics API (Defferred Shader Retrieval Failed)"); return nullptr;
		}
	}
	uintptr_t DefferedRenderer::GetBuffers(uint32_t bufferInd)
	{
		switch(RendererAPI::GetAPI()) 
		{
			case GraphicsAPI::OpenGL: 	return OpenGLDeferredRenderer::GetBuffers(bufferInd);
			case GraphicsAPI::Metal: 	return MetalDeferredRenderer::GetBuffers(bufferInd);
			case GraphicsAPI::None:
			default: 					CN_CORE_ERROR("Invalid Graphics API (Buffer Retrieval Failed)"); return 0;
		}
	}
}
