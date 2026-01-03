#pragma once
#include "Crimson/Renderer/FrameBuffer.h"

namespace Crimson {
	class MetalFrameBuffer : public FrameBuffer
	{
	public:
		MetalFrameBuffer(const FrameBufferSpecification& spec);
		~MetalFrameBuffer();
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
	
		void* m_Texture; // id<MTLTexture>
		void* m_SceneTexture; // id<MTLTexture>
		void* m_DepthTexture; // id<MTLTexture>
		void* m_RenderID; // id<MTLTexture>

		FrameBufferSpecification m_Specification;
		
	private:
		void invalidate(const FrameBufferSpecification& spec);
	};
}
