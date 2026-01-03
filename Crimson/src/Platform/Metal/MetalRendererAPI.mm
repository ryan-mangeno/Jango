#include "cnpch.h"
#include "MetalRendererAPI.h"
#include "MetalBuffer.h"
#include "Crimson/Core/Application.h" 
#include "Crimson/Core/PrimCodes.h" 

#import <Metal/Metal.h>
#import <QuartzCore/QuartzCore.h> 
#import <Cocoa/Cocoa.h>           

#define GLFW_EXPOSE_NATIVE_COCOA
#include <GLFW/glfw3.h>
#include <GLFW/glfw3native.h>

namespace Crimson {

    void* MetalRendererAPI::s_Device = nullptr;
    void* MetalRendererAPI::s_CommandQueue = nullptr;
    void* MetalRendererAPI::s_CurrentEncoder = nullptr;
    void* MetalRendererAPI::s_CurrentCommandBuffer = nullptr;
    void* MetalRendererAPI::s_DepthStencilState = nullptr;
    void* MetalRendererAPI::s_CurrentDrawable = nullptr;

    #define MTL_DEV   ((__bridge id<MTLDevice>)s_Device)
    #define MTL_QUEUE ((__bridge id<MTLCommandQueue>)s_CommandQueue)
    #define MTL_ENC   ((__bridge id<MTLRenderCommandEncoder>)s_CurrentEncoder)
    #define MTL_BUF   ((__bridge id<MTLCommandBuffer>)s_CurrentCommandBuffer)
    #define MTL_DEPTH ((__bridge id<MTLDepthStencilState>)s_DepthStencilState)
    #define MTL_DRAW  ((__bridge id<CAMetalDrawable>)s_CurrentDrawable)

    // Helper to bind all vertex buffers
    static void BindVertexBuffers(VertexArray& va, id<MTLRenderCommandEncoder> encoder) {
        const auto& buffers = va.GetVertexBuffers();
        for (uint32_t i = 0; i < buffers.size(); i++) {
            auto metalVB = std::dynamic_pointer_cast<MetalVertexBuffer>(buffers[i]);
            if (metalVB) {
                [encoder setVertexBuffer:(__bridge id<MTLBuffer>)metalVB->GetNativeBuffer()
                                  offset:0 
                                 atIndex:i]; 
            }
        }
    }

    MetalRendererAPI::MetalRendererAPI() {}

    MetalRendererAPI::~MetalRendererAPI()
    {
        if (s_Device) CFRelease(s_Device);
        if (s_CommandQueue) CFRelease(s_CommandQueue);
        if (s_DepthStencilState) CFRelease(s_DepthStencilState);
        
        s_Device = nullptr;
        s_CommandQueue = nullptr;
        s_DepthStencilState = nullptr;
    }

    void MetalRendererAPI::Init()
    {
        id<MTLDevice> mtlDevice = MTLCreateSystemDefaultDevice();
        s_Device = (void*)CFBridgingRetain(mtlDevice);

        id<MTLCommandQueue> cmdQ = [mtlDevice newCommandQueue];
        s_CommandQueue = (void*)CFBridgingRetain(cmdQ);
        s_CurrentCommandBuffer = nullptr; 

        CN_CORE_INFO("Metal Device: {0}", [[mtlDevice name] UTF8String]);

        // Depth Stencil State
        MTLDepthStencilDescriptor *depthDesc = [[MTLDepthStencilDescriptor alloc] init];
        depthDesc.depthCompareFunction = MTLCompareFunctionLess; 
        depthDesc.depthWriteEnabled = YES;
        id<MTLDepthStencilState> depthSS = [mtlDevice newDepthStencilStateWithDescriptor:depthDesc];
        s_DepthStencilState = (void*)CFBridgingRetain(depthSS);
    }

    void MetalRendererAPI::SetViewPort(unsigned int Width, unsigned int Height)
    {
        if (!s_CurrentEncoder) return;
        MTLViewport viewport = { 0.0, 0.0, (double)Width, (double)Height, 0.0, 1.0 };
        [MTL_ENC setViewport:viewport];
    }

    glm::vec2 MetalRendererAPI::GetViewportSize()
    {
        auto& win = Application::Get().GetWindow(); 
        return { (float)win.GetWidth(), (float)win.GetHeight() };
    }

    void MetalRendererAPI::ClearColor(const glm::vec4& color)
    {
        m_ClearColor = color;
    }

    void MetalRendererAPI::Clear()
    {
        // Empty, Metal handles clears via LoadAction in FrameBuffer::Bind()
    }

    void MetalRendererAPI::FlushEncoder()
    {
        if (s_CurrentEncoder) {
            [MTL_ENC endEncoding];
            CFRelease(s_CurrentEncoder);
            s_CurrentEncoder = nullptr;
        }
    }

    void MetalRendererAPI::EndEncoding()
    {
        FlushEncoder();

        if (s_CurrentCommandBuffer) {
            id<MTLCommandBuffer> cmdBuf = MTL_BUF;
            if (s_CurrentDrawable) {
                [cmdBuf presentDrawable:MTL_DRAW];
                CFRelease(s_CurrentDrawable);
                s_CurrentDrawable = nullptr;
            }
            [cmdBuf commit];
            CFRelease(s_CurrentCommandBuffer);
            s_CurrentCommandBuffer = nullptr;
        }
    }

    // ====================================================================================
    // DRAW CALLS
    // ====================================================================================

    void MetalRendererAPI::DrawIndex(VertexArray& vertexarray, unsigned int renderingMode)
    {
       if (!s_CurrentEncoder) return;
        
        BindVertexBuffers(vertexarray, MTL_ENC);

        auto metalIB = std::dynamic_pointer_cast<MetalIndexBuffer>(vertexarray.GetIndexBuffer());
        if (!metalIB) return;

        // WIREMESH LOGIC: 
        // If CN_LINE is passed, we switch to "Wireframe Mode" 
        // But we still draw "Triangles" as the primitive.
        MTLTriangleFillMode fillMode = (renderingMode == CN_LINE) ? MTLTriangleFillModeLines : MTLTriangleFillModeFill;
        [MTL_ENC setTriangleFillMode:fillMode];

        [MTL_ENC drawIndexedPrimitives:MTLPrimitiveTypeTriangle
                            indexCount:metalIB->GetCount()
                             indexType:MTLIndexTypeUInt32
                           indexBuffer:(__bridge id<MTLBuffer>)metalIB->GetNativeBuffer()
                     indexBufferOffset:0];
    }

    void MetalRendererAPI::DrawArrays(VertexArray& vertexarray, size_t count, int first)
    {
        if (!s_CurrentEncoder) return;

        BindVertexBuffers(vertexarray, MTL_ENC);
        
        // Default to Fill
        [MTL_ENC setTriangleFillMode:MTLTriangleFillModeFill];

        [MTL_ENC drawPrimitives:MTLPrimitiveTypeTriangle
                    vertexStart:first
                    vertexCount:count];
    }

    void MetalRendererAPI::DrawArrays(VertexArray& vertexarray, size_t count, unsigned int renderingMode, int first)
    {
        if (!s_CurrentEncoder) return;

        BindVertexBuffers(vertexarray, MTL_ENC);

        // WIREMESH LOGIC
        MTLTriangleFillMode fillMode = (renderingMode == CN_LINE) ? MTLTriangleFillModeLines : MTLTriangleFillModeFill;
        [MTL_ENC setTriangleFillMode:fillMode];
        
        [MTL_ENC drawPrimitives:MTLPrimitiveTypeTriangle
                    vertexStart:first
                    vertexCount:count];
    }

    void MetalRendererAPI::DrawInstancedArrays(VertexArray& vertexarray, size_t count, size_t instance_count, int first)
    {
        if (!s_CurrentEncoder) return;

        BindVertexBuffers(vertexarray, MTL_ENC);
        [MTL_ENC setTriangleFillMode:MTLTriangleFillModeFill];

        [MTL_ENC drawPrimitives:MTLPrimitiveTypeTriangle
                    vertexStart:first
                    vertexCount:count
                  instanceCount:instance_count];
    }

    // ====================================================================================
    // INDIRECT DRAWING
    // ====================================================================================

    void MetalRendererAPI::DrawArraysIndirect(VertexArray& vertexarray, uint32_t indirectBufferID)
    {
        if (!s_CurrentEncoder) return;
        id<MTLBuffer> indirectBuf = (__bridge id<MTLBuffer>)(void*)(uintptr_t)indirectBufferID;
        if (!indirectBuf) return;

        BindVertexBuffers(vertexarray, MTL_ENC);
        [MTL_ENC setTriangleFillMode:MTLTriangleFillModeFill];

        [MTL_ENC drawPrimitives:MTLPrimitiveTypeTriangle
                 indirectBuffer:indirectBuf
           indirectBufferOffset:0];
    }

    void MetalRendererAPI::DrawElementsIndirect(VertexArray& vertexarray, uint32_t indirectBufferID)
    {
        if (!s_CurrentEncoder) return;
        id<MTLBuffer> indirectBuf = (__bridge id<MTLBuffer>)(void*)(uintptr_t)indirectBufferID;
        auto metalIB = std::dynamic_pointer_cast<MetalIndexBuffer>(vertexarray.GetIndexBuffer());
        
        if (!indirectBuf || !metalIB) return;

        BindVertexBuffers(vertexarray, MTL_ENC);
        [MTL_ENC setTriangleFillMode:MTLTriangleFillModeFill];

        [MTL_ENC drawIndexedPrimitives:MTLPrimitiveTypeTriangle
                             indexType:MTLIndexTypeUInt32
                           indexBuffer:(__bridge id<MTLBuffer>)metalIB->GetNativeBuffer()
                     indexBufferOffset:0
                        indirectBuffer:indirectBuf
                  indirectBufferOffset:0];
    }
    
    void MetalRendererAPI::DrawElementsIndirect(VertexArray& vertexarray, DrawElementsIndirectCommand& indirectCommand)
    {
        if (!s_CurrentEncoder) return;

        // Metal cannot draw from a struct directly. Must copy to buffer
        id<MTLBuffer> tempCmdBuffer = [MTL_DEV newBufferWithBytes:&indirectCommand 
                                                           length:sizeof(DrawElementsIndirectCommand) 
                                                          options:MTLResourceStorageModeShared];

        auto metalIB = std::dynamic_pointer_cast<MetalIndexBuffer>(vertexarray.GetIndexBuffer());
        if (!metalIB) return;

        BindVertexBuffers(vertexarray, MTL_ENC);
        [MTL_ENC setTriangleFillMode:MTLTriangleFillModeFill];

        [MTL_ENC drawIndexedPrimitives:MTLPrimitiveTypeTriangle
                             indexType:MTLIndexTypeUInt32
                           indexBuffer:(__bridge id<MTLBuffer>)metalIB->GetNativeBuffer()
                     indexBufferOffset:0
                        indirectBuffer:tempCmdBuffer
                  indirectBufferOffset:0];
    }

    // used for Debug Lines (Actual Line Primitives)
    void MetalRendererAPI::DrawLine(VertexArray& vertexarray, uint32_t count)
    {
        if (!s_CurrentEncoder) return;

        BindVertexBuffers(vertexarray, MTL_ENC);
        
        [MTL_ENC setTriangleFillMode:MTLTriangleFillModeFill]; 

        [MTL_ENC drawPrimitives:MTLPrimitiveTypeLine
                    vertexStart:0
                    vertexCount:count];
    }
}