#include "cnpch.h"

#include "MetalRendererAPI.h"
#include "MetalBuffer.h"
#include "MetalVertexArray.h"

#import <Metal/Metal.h>

namespace Crimson {

    MetalVertexArray::MetalVertexArray() {}
    MetalVertexArray::~MetalVertexArray() {}

    void MetalVertexArray::Bind() const
    {
        // get the current command encoder
        id<MTLRenderCommandEncoder> encoder = (__bridge id<MTLRenderCommandEncoder>)MetalRendererAPI::GetCurrentEncoder();
        
        // loop through stored buffers and bind them to slots 0, 1, 2
        for (uint32_t i = 0; i < m_VertexBuffer.size(); i++)
        {
            // retrieve the native metal buffer
            Ref<MetalVertexBuffer> metalVB = std::static_pointer_cast<MetalVertexBuffer>(m_VertexBuffer[i]);
            id<MTLBuffer> mtlBuf = (__bridge id<MTLBuffer>)metalVB->GetNativeBuffer();
            
            // offset 0 is standard
            [encoder setVertexBuffer:mtlBuf offset:0 atIndex:i];
        }
    }

    void MetalVertexArray::UnBind() const
    {
        // no op for Metal
    }

    void MetalVertexArray::AddBuffer(Ref<BufferLayout>& layout, Ref<VertexBuffer>& vbo)
    {
        // Metal Shader Reflection handles structure
        m_VertexBuffer.push_back(vbo);
    }

    void MetalVertexArray::SetIndexBuffer(Ref<IndexBuffer> indexBuffer)
    {
        m_IndexBuffer = indexBuffer;
    }
}