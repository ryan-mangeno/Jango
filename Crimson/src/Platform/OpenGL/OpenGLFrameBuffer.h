#pragma once
#include "Crimson/Renderer/FrameBuffer.h"
#include "Crimson/Renderer/GPUHandle.h"

namespace Crimson {
	class OpenGLFrameBuffer : public FrameBuffer
	{
	public:
		OpenGLFrameBuffer(const FrameBufferSpecification& spec);
		~OpenGLFrameBuffer();
		inline virtual GPUHandle GetSceneTextureHandle() override { return GPUHandle(m_SceneTexture); }
		inline virtual GPUHandle GetDepthTextureHandle() override { return GPUHandle(m_DepthTexture); }
		inline virtual const FrameBufferSpecification& GetSpecification() override { return m_Specification; }
		virtual void Bind() override;
		virtual void UnBind() override;
		virtual void Resize(uint32_t width, uint32_t height) override;
		virtual void ClearFrameBuffer()override;
		virtual void BindFramebufferTexture(uint32_t slot) override;
		virtual void BindFramebufferDepthTexture(uint32_t slot) override;
	private:
		uint32_t m_RenderID=0,m_SceneTexture=0,m_DepthTexture=0;
		FrameBufferSpecification m_Specification;
	private:
		void invalidate(const FrameBufferSpecification& spec);
	};
}
