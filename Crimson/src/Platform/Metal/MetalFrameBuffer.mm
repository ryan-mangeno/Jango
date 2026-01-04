#include "cnpch.h"
#include "MetalFrameBuffer.h"
#include "MetalRendererAPI.h" 

#import <Metal/Metal.h>

namespace Crimson {

    MetalFrameBuffer::MetalFrameBuffer(const FrameBufferSpecification& spec)
        : m_Specification(spec)
    {
        invalidate(m_Specification);
    }

    MetalFrameBuffer::~MetalFrameBuffer()
    {
        // release Metal resources (bridged pointers)
        if (m_SceneTexture) { CFRelease(m_SceneTexture); m_SceneTexture = nullptr; }
        if (m_DepthTexture) { CFRelease(m_DepthTexture); m_DepthTexture = nullptr; }
    }

    void MetalFrameBuffer::invalidate(const FrameBufferSpecification& spec)
    {
        CN_PROFILE_FUNCTION();

        if (m_SceneTexture) { CFRelease(m_SceneTexture); m_SceneTexture = nullptr; }
        if (m_DepthTexture) { CFRelease(m_DepthTexture); m_DepthTexture = nullptr; }

        id<MTLDevice> device = (__bridge id<MTLDevice>)MetalRendererAPI::GetDevice();

        // Color Attachment
        // GL_RGB16F equivalent in Metal is RGBA16Float (Metal prefers 4-component render targets)
        MTLTextureDescriptor* colorDesc = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA16Float 
                                                                                             width:spec.Width
                                                                                            height:spec.Height 
                                                                                            mipmapped:NO];
        colorDesc.usage = MTLTextureUsageRenderTarget | MTLTextureUsageShaderRead;
        colorDesc.storageMode = MTLStorageModePrivate; // GPU only
        
        m_SceneTexture = (__bridge_retained void*)[device newTextureWithDescriptor:colorDesc];

        // Depth Attachment
        // GL_DEPTH_COMPONENT32 equivalent
        MTLTextureDescriptor* depthDesc = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatDepth32Float 
                                                                                             width:spec.Width 
                                                                                            height:spec.Height 
                                                                                            mipmapped:NO];
        depthDesc.usage = MTLTextureUsageRenderTarget | MTLTextureUsageShaderRead;
        depthDesc.storageMode = MTLStorageModePrivate;

        m_DepthTexture = (__bridge_retained void*)[device newTextureWithDescriptor:depthDesc];
    }

    void MetalFrameBuffer::Bind()
    {
        MetalRendererAPI::FlushEncoder(); 

        id<MTLCommandBuffer> cmdBuffer = (__bridge id<MTLCommandBuffer>)MetalRendererAPI::GetCurrentCommandBuffer();
        
        // Pass Descriptor
        MTLRenderPassDescriptor* passDesc = [MTLRenderPassDescriptor renderPassDescriptor];
        
        // Color Attachment 0
        passDesc.colorAttachments[0].texture = (__bridge id<MTLTexture>)m_SceneTexture;
        passDesc.colorAttachments[0].loadAction = MTLLoadActionClear; // Acts like glClear(COLOR_BIT)
        passDesc.colorAttachments[0].storeAction = MTLStoreActionStore; // Save result
        passDesc.colorAttachments[0].clearColor = MTLClearColorMake(0.1, 0.1, 0.1, 1.0);

        // Depth Attachment
        passDesc.depthAttachment.texture = (__bridge id<MTLTexture>)m_DepthTexture;
        passDesc.depthAttachment.loadAction = MTLLoadActionClear; // Acts like glClear(DEPTH_BIT)
        passDesc.depthAttachment.storeAction = MTLStoreActionStore;
        passDesc.depthAttachment.clearDepth = 1.0;

        // Create new Encoder
        id<MTLRenderCommandEncoder> encoder = [cmdBuffer renderCommandEncoderWithDescriptor:passDesc];
        encoder.label = @"Custom FrameBuffer Pass";

        // Set this as the active encoder so Renderer::Draw() uses it
        MetalRendererAPI::SetCurrentEncoder((__bridge void*)encoder);
        MTLViewport vp = { 0.0, 0.0, (double)m_Specification.Width, (double)m_Specification.Height, 0.0, 1.0 };
        [encoder setViewport:vp];
    }

    void MetalFrameBuffer::UnBind()
    {
        // just stop encoding, next pass ( screen or other fbo ) will start its own encoder so this might not be necesary every time
        MetalRendererAPI::FlushEncoder();
    }

    void MetalFrameBuffer::Resize(uint32_t width, uint32_t height)
    {
        if (width == 0 || height == 0 || width > 8192 || height > 8192)
        {
            CN_CORE_WARN("Attempted to resize framebuffer to {0}, {1}", width, height);
            return;
        }

        m_Specification.Width = width;
        m_Specification.Height = height;
        invalidate(m_Specification);
    }

    void MetalFrameBuffer::BindFramebufferTexture(uint32_t slot)
    {
        // equivalent to glActiveTexture(slot) + glBindTexture(GL_TEXTURE_2D, id)
        // We grab cur encoder and bind this FBO's texture as input
        id<MTLRenderCommandEncoder> encoder = (__bridge id<MTLRenderCommandEncoder>)MetalRendererAPI::GetCurrentEncoder();
        
        if (encoder && m_SceneTexture) {
            [encoder setFragmentTexture:(__bridge id<MTLTexture>)m_SceneTexture atIndex:slot];
        }
    }

    // Bind this FBO's depth output as a texture (e.g., for Shadow Mapping)
    void MetalFrameBuffer::BindFramebufferDepthTexture(uint32_t slot)
    {
        id<MTLRenderCommandEncoder> encoder = (__bridge id<MTLRenderCommandEncoder>)MetalRendererAPI::GetCurrentEncoder();
        if (encoder && m_DepthTexture) {
            [encoder setFragmentTexture:(__bridge id<MTLTexture>)m_DepthTexture atIndex:slot];
        }
    }

    void MetalFrameBuffer::ClearFrameBuffer()
    {
        // In Metal, if you want to clear a framebuffer explicitly without drawing anything
        // You create a dummy render pass that Clears (LoadAction) and Stores (StoreAction)
        
        MetalRendererAPI::FlushEncoder(); // stop whatever is happening

        id<MTLCommandBuffer> cmdBuffer = (__bridge id<MTLCommandBuffer>)MetalRendererAPI::GetCurrentCommandBuffer();
        MTLRenderPassDescriptor* passDesc = [MTLRenderPassDescriptor renderPassDescriptor];
        
        passDesc.colorAttachments[0].texture = (__bridge id<MTLTexture>)m_SceneTexture;
        passDesc.colorAttachments[0].loadAction = MTLLoadActionClear;
        passDesc.colorAttachments[0].storeAction = MTLStoreActionStore;
        passDesc.colorAttachments[0].clearColor = MTLClearColorMake(0, 0, 0, 1); // Black Clear

        // quickly start and end the encoder to trigger the clear
        id<MTLRenderCommandEncoder> encoder = [cmdBuffer renderCommandEncoderWithDescriptor:passDesc];
        [encoder endEncoding];
    }
}