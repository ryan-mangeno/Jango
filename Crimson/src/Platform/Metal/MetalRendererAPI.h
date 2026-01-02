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
        virtual void SetViewPort(uint32_t Width, uint32_t Height) override;
        virtual glm::vec2 GetViewportSize() override;

        virtual void ClearColor(const glm::vec4& color) override;
        virtual void Clear() override;

        virtual void DrawIndex(VertexArray& vertexArray, uint32_t renderingMode = 0) override;
        virtual void DrawArrays(VertexArray& vertexArray, size_t count, int first = 0) override;
        virtual void DrawArrays(VertexArray& vertexArray, size_t count, uint32_t renderingMode, int first) override;
        
        virtual void DrawInstancedArrays(VertexArray& vertexArray, size_t count, size_t instanceCount, int first = 0) override;
        
        virtual void DrawArraysIndirect(VertexArray& vertexArray, uint32_t indirectBufferID) override;
        virtual void DrawElementsIndirect(VertexArray& vertexArray, uint32_t indirectBufferID) override;
        virtual void DrawElementsIndirect(VertexArray& vertexArray, DrawElementsIndirectCommand& indirectCommand) override;

        virtual void DrawLine(VertexArray& vertexArray, uint32_t count) override;

        // Metal Accessors, 
        inline static void* GetDevice() { return s_Device; }                             // id<MTLDevice>
        inline static void* GetCurrentEncoder() { return s_CurrentEncoder; }             // id<MTLRenderCommandEncoder> 
        inline static void* GetCurrentCommandBuffer() { return s_CurrentCommandBuffer; } // id<MTLCommandBuffer>
        inline static void* GetCommandQueue() { return s_CommandQueue; }                 // id<MTLCommandQueue>
        
        // This usually needs to be called by Window/Swapchain system to end the frame
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