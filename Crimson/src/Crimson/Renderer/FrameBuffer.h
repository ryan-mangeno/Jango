#pragma once

#include "Crimson/Core/Core.h"
#include "Crimson/Renderer/GPUHandle.h"
#include <glm/glm.hpp>

namespace Crimson {

    struct FrameBufferSpecification {
        uint32_t Width, Height;
        bool SwapChainTarget = false;

        FrameBufferSpecification() = default;
        FrameBufferSpecification(uint32_t width, uint32_t height)
            : Width(width), Height(height)
        {
        }
	};
	class FrameBuffer
	{
	public:
		static Ref<FrameBuffer> Create(const FrameBufferSpecification& spec);
		inline virtual const FrameBufferSpecification& GetSpecification() = 0;
		virtual void Bind()=0;
		virtual void UnBind()=0;
		inline virtual GPUHandle GetSceneTextureHandle() = 0;
		inline virtual GPUHandle GetDepthTextureHandle() = 0;
		inline virtual PlatformGPUHandle GetSceneTextureRef() { return GetSceneTextureHandle().ToPlatform();}
		inline virtual PlatformGPUHandle GetDepthTextureRef() { return GetDepthTextureHandle().ToPlatform();}
		virtual void Resize(uint32_t width, uint32_t height) = 0;
		virtual void ClearFrameBuffer() = 0;
		virtual void BindFramebufferTexture(uint32_t slot) = 0;
		virtual void BindFramebufferDepthTexture(uint32_t slot) = 0;

	};
}