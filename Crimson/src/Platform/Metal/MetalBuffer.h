#pragma once

#include "Crimson/Renderer/Buffer.h"

namespace Crimson {

    //                          Vertex Buffer

    class MetalVertexBuffer : public VertexBuffer {
    public:
        MetalVertexBuffer(const float* data, uint32_t size);
        
        // Dynamic creation (mutable by default)
        MetalVertexBuffer(uint32_t size, BufferStorageType Storage_Type = BufferStorageType::MUTABLE);
        
        virtual ~MetalVertexBuffer();

        virtual void Bind() const override;
        virtual void UnBind() const override;

        virtual void SetData(uint32_t size, const void* data) override;
        
        // metal makes mapping very easy (Shared Memory)
        virtual void* MapBuffer(uint32_t size) override; 

        virtual const BufferLayout& GetLayout() const { return m_Layout; }
        virtual void SetLayout(const BufferLayout& layout) { m_Layout = layout; }

        // METAL SPECIFIC: The Renderer needs this to call [encoder setVertexBuffer:]
        void* GetNativeBuffer() const { return m_Buffer; }

    private:
        void* m_Buffer; // id<MTLBuffer>
        BufferLayout m_Layout;
    };

    //                          Index Buffer
    class MetalIndexBuffer : public IndexBuffer {
    public:
        MetalIndexBuffer(const uint32_t* data, uint32_t count);
        virtual ~MetalIndexBuffer();

        virtual void Bind() const override;
        virtual void UnBind() const override;

        virtual uint32_t GetCount() const override { return m_Elements; }

        // METAL SPECIFIC
        void* GetNativeBuffer() const { return m_Buffer; }

    private:
        void* m_Buffer; // Stores id<MTLBuffer> (Bridged)
        uint32_t m_Elements;
    };
}