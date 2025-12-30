#include "cnpch.h"
#include "Platform/OpenGL/OpenGLDeferredRenderer.h"
#include "DeferredRenderer.h"

namespace Crimson
{
	void DefferedRenderer::Init(int width, int height)
	{
		OpenGLDeferredRenderer::Init(width,height);
	}
	void DefferedRenderer::GenerateGBuffers(Scene* scene, bool withWater)
	{
		OpenGLDeferredRenderer::CreateBuffers(scene, withWater);
	}
	void DefferedRenderer::DeferredRenderPass()
	{
		OpenGLDeferredRenderer::DeferredPass();
	}
	Ref<Shader> DefferedRenderer::GetDeferredPassShader()
	{
		return OpenGLDeferredRenderer::GetDeferredShader();
	}
	uint32_t DefferedRenderer::GetBuffers(int bufferInd)
	{
		return OpenGLDeferredRenderer::GetBuffers(bufferInd);
	}
}
