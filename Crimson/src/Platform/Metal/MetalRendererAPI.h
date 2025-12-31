#pragma once
#include "Crimson/Renderer/RendererAPI.h"
#include <glm/glm.hpp>

namespace Crimson {

    class MetalRendererAPI : public RendererAPI
    {
    public:
        MetalRendererAPI();
        ~MetalRendererAPI();

        virtual void Init() override;
        virtual void SetViewPort(unsigned int Width, unsigned int Height) override;
        virtual glm::vec2 GetViewportSize() override;

        virtual void ClearColor(const glm::vec4& color) override;
        virtual void Clear() override;

        virtual void DrawIndex(VertexArray& vertexArray, unsigned int renderingMode = 0) override;
        virtual void DrawArrays(VertexArray& vertexArray, size_t count, int first = 0) override;
        virtual void DrawArrays(VertexArray& vertexArray, size_t count, unsigned int renderingMode, int first) override;
        
        virtual void DrawInstancedArrays(VertexArray& vertexArray, size_t count, size_t instanceCount, int first = 0) override;
        
        // Indirect calls
        virtual void DrawArraysIndirect(VertexArray& vertexArray, uint32_t indirectBufferID) override;
        virtual void DrawElementsIndirect(VertexArray& vertexArray, uint32_t indirectBufferID) override;
        virtual void DrawElementsIndirect(VertexArray& vertexArray, DrawElementsIndirectCommand& indirectCommand) override;

        virtual void DrawLine(VertexArray& vertexArray, uint32_t count) override;

        // Metal Accessors, 
        // must cast to id<MTLDevice> to keep C++ happy
        inline static void* GetDevice() { return s_Device; }
        // same for this ... must cast to id<MTLRenderCommandEncoder> 
        inline static void* GetCurrentEncoder() { return s_CurrentEncoder; }
        // id<MTLCommandBuffer>
        inline static void* GetCurrentCommandBuffer() { return s_CurrentCommandBuffer; }
        
        // This usually needs to be called by your Window/Swapchain system to end the frame
        void EndEncoding(); 

    private:
        static void* s_Device; // id<MTLDevice>
        static void* s_CommandQueue; // id<MTLCommandQueue>
        static void* s_CurrentEncoder; // id<MTLRenderCommandEncoder>
        static void* s_CurrentCommandBuffer; // id<MTLCommandBuffer>
        // Metal requires explicit depth state creation
        void* m_DepthStencilState; // id<MTLDepthStencilState>
        
        glm::vec4 m_ClearColor = {0.0f, 0.0f, 0.0f, 1.0f};
    };
}