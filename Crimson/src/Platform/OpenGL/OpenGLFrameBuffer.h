#pragma once
#include "Crimson/Renderer/FrameBuffer.h"

namespace Crimson {
	class OpenGLFrameBuffer : public FrameBuffer
	{
	public:
		OpenGLFrameBuffer(const FrameBufferSpecification& spec);
		~OpenGLFrameBuffer();
		inline virtual uint32_t GetSceneTextureID() override { return m_SceneTexture; }
		inline virtual uint32_t GetDepthTextureID() override { return m_DepthTexture; }
		inline virtual const FrameBufferSpecification& GetSpecification() override { return Specification; }
		virtual void Bind() override;
		virtual void UnBind() override;
		virtual void Resize(uint32_t width, uint32_t height) override;
		virtual void ClearFrameBuffer()override;
		virtual void BindFramebufferTexture(int slot) override;
		virtual void BindFramebufferDepthTexture(int slot) override;
	private:
		uint32_t m_RenderID=0,m_SceneTexture=0,m_DepthTexture=0;
		FrameBufferSpecification Specification;
	private:
		void invalidate(const FrameBufferSpecification& spec);
	};
}

