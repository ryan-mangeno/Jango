#pragma once
#include "Crimson/Renderer/FrameBuffer.h"

namespace Crimson {
	class MetalFrameBuffer : public FrameBuffer
	{
	public:
		MetalFrameBuffer(const FrameBufferSpecification& spec);
		~MetalFrameBuffer();
		inline virtual unsigned int GetSceneTextureID() override { return m_SceneTexture; }
		inline virtual unsigned int GetDepthTextureID() override { return m_DepthTexture; }
		inline virtual const FrameBufferSpecification& GetSpecification() override { return Specification; }
		virtual void Bind() override;
		virtual void UnBind() override;
		virtual void Resize(unsigned int width, unsigned int height) override;
		virtual void ClearFrameBuffer()override;
		virtual void BindFramebufferTexture(int slot) override;
		virtual void BindFramebufferDepthTexture(int slot) override;
	private:
		unsigned int m_RenderID=0,m_SceneTexture=0,m_DepthTexture=0;
		FrameBufferSpecification Specification;
	private:
		void invalidate(const FrameBufferSpecification& spec);
	};
}

