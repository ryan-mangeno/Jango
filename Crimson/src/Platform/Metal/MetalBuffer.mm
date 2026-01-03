#include "cnpch.h"
#include "MetalBuffer.h"
#include "MetalRendererAPI.h"

#import <Metal/Metal.h>

namespace Crimson {

    //  VERTEX BUFFER

    MetalVertexBuffer::MetalVertexBuffer(const float* data, uint32_t size)
    {
        id<MTLDevice> device = (__bridge id<MTLDevice>)MetalRendererAPI::GetDevice();

        // For static data (vertices that dont change), we copy it immediately
        m_Buffer = (__bridge_retained void*)[device newBufferWithBytes:data 
                                                                length:size 
                                                               options:MTLResourceStorageModeShared];
    }

    MetalVertexBuffer::MetalVertexBuffer(uint32_t size, BufferStorageType Storage_Type)
    {
        id<MTLDevice> device = (__bridge id<MTLDevice>)MetalRendererAPI::GetDevice();

        MTLResourceOptions options = MTLResourceStorageModeShared;

        if (Storage_Type == BufferStorageType::MUTABLE) 
        {
            options = MTLResourceStorageModeShared | MTLResourceCPUCacheModeWriteCombined;
        }

        m_Buffer = (__bridge_retained void*)[device newBufferWithLength:size options:options];
    }

    MetalVertexBuffer::~MetalVertexBuffer()
    {
        if (m_Buffer)
        {
            CFRelease(m_Buffer);
            m_Buffer = nullptr;
        }
    }

    void MetalVertexBuffer::Bind() const
    {
    }

    void MetalVertexBuffer::UnBind() const
    {
    }

    void MetalVertexBuffer::SetData(uint32_t size, const void* data)
    {
        if (!m_Buffer) return;

        id<MTLBuffer> buffer = (__bridge id<MTLBuffer>)m_Buffer;
        
        void* bufferPointer = [buffer contents];
        memcpy(bufferPointer, data, size);
        
        // Hint to the GPU that we modified this range (mostly for Managed mode on macOS
        // but good practice if storage modes are switched
        [buffer didModifyRange:NSMakeRange(0, size)];
    }

    void* MetalVertexBuffer::MapBuffer(uint32_t size)
    {
        if (!m_Buffer) return nullptr;
        
        // return raw pointer to the buffer memory so the renderer can write to it directly
        return [(__bridge id<MTLBuffer>)m_Buffer contents];
    }

    // INDEX BUFFER

    MetalIndexBuffer::MetalIndexBuffer(const uint32_t* data, uint32_t size)
    {
        m_Elements = size / sizeof(uint32_t);

        id<MTLDevice> device = (__bridge id<MTLDevice>)MetalRendererAPI::GetDevice();

        // create buf and copy index data
        m_Buffer = (__bridge_retained void*)[device newBufferWithBytes:data 
                                                                length:size 
                                                               options:MTLResourceStorageModeShared];
    }

    MetalIndexBuffer::~MetalIndexBuffer()
    {
        if (m_Buffer)
        {
            CFRelease(m_Buffer);
            m_Buffer = nullptr;
        }
    }

    void MetalIndexBuffer::Bind() const
    {
    }

    void MetalIndexBuffer::UnBind() const
    {
    }
}