#include "cnpch.h"
#include "MetalFrameBuffer.h"
#include "glad/glad.h"
#include "Crimson/Core/Log.h"

namespace Crimson {
    MetalFrameBuffer::MetalFrameBuffer(const FrameBufferSpecification& spec)
    {
        invalidate(spec);
    }
    MetalFrameBuffer::~MetalFrameBuffer()
    {
    }
    void MetalFrameBuffer::Bind()
    {
    }
    void MetalFrameBuffer::UnBind()
    {
    }
    void MetalFrameBuffer::Resize(unsigned int width, unsigned int height)
    {
    }
    void MetalFrameBuffer::ClearFrameBuffer()
    {
    }
    void MetalFrameBuffer::BindFramebufferTexture(int slot)
    {
    }
    void MetalFrameBuffer::BindFramebufferDepthTexture(int slot)
    {
    }
    void MetalFrameBuffer::invalidate(const FrameBufferSpecification& spec)
    {
    }
}