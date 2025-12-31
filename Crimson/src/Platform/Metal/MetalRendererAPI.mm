#include "cnpch.h"

#include "MetalRendererAPI.h"
#include "Crimson/Core/Application.h" 
#include "Crimson/Core/PrimCodes.h"

#import <Metal/Metal.h>
#import <QuartzCore/QuartzCore.h> 
#import <Cocoa/Cocoa.h>           

#define GLFW_EXPOSE_NATIVE_COCOA
#include <GLFW/glfw3.h>
#include <GLFW/glfw3native.h>

namespace Crimson {

    void* MetalRendererAPI::s_Device = nullptr; // id<MTLDevice>
    void* MetalRendererAPI::s_CommandQueue = nullptr;; // id<MTLCommandQueue>
    void* MetalRendererAPI::s_CurrentEncoder = nullptr;; // id<MTLRenderCommandEncoder>
    void* MetalRendererAPI::s_CurrentCommandBuffer = nullptr; // id<MTLCommandBuffer>

    #define MTL_DEV   ((__bridge id<MTLDevice>)s_Device)
    #define MTL_QUEUE ((__bridge id<MTLCommandQueue>)s_CommandQueue)
    #define MTL_ENC   ((__bridge id<MTLRenderCommandEncoder>)s_CurrentEncoder)

    MetalRendererAPI::MetalRendererAPI()
    {
    }

    MetalRendererAPI::~MetalRendererAPI()
    {
        // cleanup metal objects (ARC usually handles this in Obj-C++ if member variables)
    }

    void MetalRendererAPI::Init()
    {
        // get default device
        id<MTLDevice> mtlDevice = MTLCreateSystemDefaultDevice();
        s_Device = (__bridge_retained void*)mtlDevice;

        id<MTLCommandQueue> cmdQ = [mtlDevice newCommandQueue];
        s_CommandQueue = (__bridge_retained void*)cmdQ;

        id<MTLCommandBuffer> commandBuffer = [MTL_QUEUE commandBuffer];
        s_CurrentCommandBuffer = (__bridge_retained void*)commandBuffer;

        CN_CORE_INFO("Metal Device: {0}", [[mtlDevice name] UTF8String]);

        // Depth Stencil State (Equivalent to glEnable(GL_DEPTH_TEST))
        MTLDepthStencilDescriptor *depthDesc = [[MTLDepthStencilDescriptor alloc] init];
        depthDesc.depthCompareFunction = MTLCompareFunctionLess; // GL_LESS
        depthDesc.depthWriteEnabled = YES;
        id<MTLDepthStencilState> depthSS = [mtlDevice newDepthStencilStateWithDescriptor:depthDesc];
        m_DepthStencilState = (__bridge_retained void*)depthSS;
        
        // Note: Blending (glEnable(GL_BLEND)) is part of the PipelineState in Metal, 
        // not global state, configure blending in Shader/Material creation
    }

    void MetalRendererAPI::SetViewPort(unsigned int Width, unsigned int Height)
    {
        if (!s_CurrentEncoder) return;

        MTLViewport viewport;
        viewport.originX = 0.0;
        viewport.originY = 0.0;
        viewport.width = (double)Width;
        viewport.height = (double)Height;
        viewport.znear = 0.0;
        viewport.zfar = 1.0;

        [MTL_ENC setViewport:viewport];
    }

    glm::vec2 MetalRendererAPI::GetViewportSize()
    {
        // Metal doesn't really store "current viewport" globally like GL
        // should query Window/Swapchain logic instead
        // For now returning cached application size or 0
        auto& win = Application::Get().GetWindow(); 
        return { (float)win.GetWidth(), (float)win.GetHeight() };
    }

    void MetalRendererAPI::ClearColor(const glm::vec4& color)
    {
        // In Metal, clear color is part of the RenderPassDescriptor, 
        // usually created at the start of a frame. We store it for the next Clear() call
        m_ClearColor = color;
    }

    void MetalRendererAPI::Clear()
    {
        // NOTE: In Metal, "Clearing" usually happens implicitly when you create the RenderEncoder
        // This function assumes we are starting a new render pass
        
        if (s_CurrentEncoder) {
            [MTL_ENC endEncoding];
            s_CurrentEncoder = nil;
        }

        void* window = Application::Get().GetWindow().GetNativeWindow();
        GLFWwindow* glfwWindow = static_cast<GLFWwindow*>(window);
        NSWindow* nswin = glfwGetCocoaWindow(glfwWindow);

        if (!nswin) {
            CN_CORE_ERROR("Could not get Cocoa Window from GLFW!");
            return;
        }

        CAMetalLayer* metalLayer = (CAMetalLayer*)nswin.contentView.layer;
        if (!metalLayer) {
            CN_CORE_ERROR("Window does not have a Metal Layer!");
            return;
        }

        // ask for the next texture (The "Drawable")
        // pauses the engine until a screen buffer is available (V-Sync logic)
        id<CAMetalDrawable> drawable = [metalLayer nextDrawable];
        if (!drawable) return;

        // setup the Render Pass (Clear Color, etc.)
        MTLRenderPassDescriptor *passDescriptor = [MTLRenderPassDescriptor renderPassDescriptor];
        
        // color attach 0 is the screen
        passDescriptor.colorAttachments[0].texture = drawable.texture; 
        passDescriptor.colorAttachments[0].loadAction = MTLLoadActionClear;
        passDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(m_ClearColor.r, m_ClearColor.g, m_ClearColor.b, m_ClearColor.a);
        passDescriptor.colorAttachments[0].storeAction = MTLStoreActionStore;

        // create encoder
        id<MTLCommandBuffer> commandBuffer = [MTL_QUEUE commandBuffer];
        
        // hook "Completed Handler" to present the drawable when the GPU is done
        [commandBuffer addCompletedHandler:^(id<MTLCommandBuffer> buffer) {
             [drawable present];
        }];

        s_CurrentEncoder = (__bridge_retained void*)[commandBuffer renderCommandEncoderWithDescriptor:passDescriptor];
        
        // 8. Re-apply global states (Metal forgets these between passes)
        [MTL_ENC setDepthStencilState:(__bridge id<MTLDepthStencilState>)m_DepthStencilState];
        [MTL_ENC setFrontFacingWinding:MTLWindingCounterClockwise];
        [MTL_ENC setCullMode:MTLCullModeBack];
    }

    void MetalRendererAPI::EndEncoding()
    {
        if (s_CurrentEncoder) {
            [MTL_ENC endEncoding];
            s_CurrentEncoder = nil;
        }
        if (s_CurrentCommandBuffer) {
            id<MTLCommandBuffer> cmdBuf = (__bridge id<MTLCommandBuffer>)s_CurrentCommandBuffer;
            [cmdBuf commit];
            
            CFRelease(s_CurrentCommandBuffer); // release bridge
            s_CurrentCommandBuffer = nullptr;
        }    
    }

    // Helper to map GL Modes to Metal
    MTLPrimitiveType GetMetalPrimitiveType(unsigned int mode) {
        // In Metal, lines and triangles are separate logic usually, 
        // but basic mapping:
        // GL_TRIANGLES -> MTLPrimitiveTypeTriangle
        // GL_LINES     -> MTLPrimitiveTypeLine
        return MTLPrimitiveTypeTriangle; 
    }

    void MetalRendererAPI::DrawIndex(VertexArray& vertexarray, unsigned int renderingMode)
    {
        // Handle Polygon Mode (Wireframe vs Fill)
        // CN_LINE -> MTLTriangleFillModeLines
        MTLTriangleFillMode fillMode = (renderingMode == CN_LINE) ? 
                                        MTLTriangleFillModeLines : MTLTriangleFillModeFill;
        [MTL_ENC setTriangleFillMode:fillMode];

        // Bind Buffers (VertexArray needs to implement Bind for Metal)
        // In Metal, this means calling [encoder setVertexBuffer:...]


        // TO FIX
        /*vertexarray.Bind(s_CurrentEncoder);

        auto& indexBuffer = vertexarray.GetIndexBuffer();
        [MTL_ENC drawIndexedPrimitives:CN_TRIANGLES
                                     indexCount:indexBuffer->GetCount()
                                      indexType:MTLIndexTypeUInt32
                                    indexBuffer:indexBuffer->GetMetalBuffer() // You need this accessor
                              indexBufferOffset:0];
        */
    }

    void MetalRendererAPI::DrawArrays(VertexArray& vertexarray, size_t count, int first)
    {
        /* TO FIX
        vertexarray.Bind(s_CurrentEncoder);
        [MTL_ENC drawPrimitives:MTLPrimitiveTypeTriangle
                             vertexStart:first
                             vertexCount:count];
        */
    }

    void MetalRendererAPI::DrawArrays(VertexArray& vertexarray, size_t count, unsigned int renderingMode, int first)
    {
        MTLTriangleFillMode fillMode = (renderingMode == CN_LINE) ? MTLTriangleFillModeLines : MTLTriangleFillModeFill;
        [MTL_ENC setTriangleFillMode:fillMode];

        /* TO FIX
        vertexarray.Bind(s_CurrentEncoder);

        if (vertexarray.GetIndexBuffer())
        {
             auto& ib = vertexarray.GetIndexBuffer();
             [MTL_ENC drawIndexedPrimitives:MTLPrimitiveTypeTriangle
                                          indexCount:ib->GetCount()
                                           indexType:MTLIndexTypeUInt32
                                         indexBuffer:ib->GetMetalBuffer()
                                   indexBufferOffset:0];
        }
        else
        {
            [MTL_ENC drawPrimitives:MTLPrimitiveTypeTriangle
                                 vertexStart:first
                                 vertexCount:count];
        }
        */
    }

    void MetalRendererAPI::DrawInstancedArrays(VertexArray& vertexarray, size_t count, size_t instance_count, int first)
    {
        /* TO FIX
        vertexarray.Bind(s_CurrentEncoder);
        [MTL_ENC drawPrimitives:MTLPrimitiveTypeTriangle
                             vertexStart:first
                             vertexCount:count
                           instanceCount:instance_count];
        */
    }

    void MetalRendererAPI::DrawArraysIndirect(VertexArray& vertexarray, uint32_t indirectBufferID)
    {
        /* TO FIX
        // NOTE: indirectBufferID in GL is a handle. In Metal you need the id<MTLBuffer> object
        // Assuming vertexArray holds reference or you look it up via ID
        id<MTLBuffer> indirectBuf = ...; // Lookup(indirectBufferID)

        vertexarray.Bind(s_CurrentEncoder);
        
        [MTL_ENC drawPrimitives:MTLPrimitiveTypeTriangle
                          indirectBuffer:indirectBuf
                    indirectBufferOffset:0];
        */
    }

    void MetalRendererAPI::DrawElementsIndirect(VertexArray& vertexarray, uint32_t indirectBufferID)
    {
        /* TO FIX
        id<MTLBuffer> indirectBuf = ...; // Lookup(indirectBufferID)
        auto& ib = vertexarray.GetIndexBuffer();

        vertexarray.Bind(s_CurrentEncoder);
        
        [MTL_ENC drawIndexedPrimitives:MTLPrimitiveTypeTriangle
                                      indexType:MTLIndexTypeUInt32
                                    indexBuffer:ib->GetMetalBuffer()
                              indexBufferOffset:0
                                 indirectBuffer:indirectBuf
                           indirectBufferOffset:0];
        */
    }
    
    void MetalRendererAPI::DrawElementsIndirect(VertexArray& vertexarray, DrawElementsIndirectCommand& indirectCommand)
    {
        /* TO FIX
        // Metal does not support raw pointers for indirect draw commands easily without a buffer
        // You must copy this struct into a MTLBuffer first
        
        id<MTLBuffer> cmdBuffer = [s_Device newBufferWithBytes:&indirectCommand 
                                                        length:sizeof(DrawElementsIndirectCommand) 
                                                       options:MTLResourceStorageModeShared];
        
        vertexarray.Bind(s_CurrentEncoder);
        auto& ib = vertexarray.GetIndexBuffer();

        [MTL_ENC drawIndexedPrimitives:MTLPrimitiveTypeTriangle
                                      indexType:MTLIndexTypeUInt32
                                    indexBuffer:ib->GetMetalBuffer()
                              indexBufferOffset:0
                                 indirectBuffer:cmdBuffer
                           indirectBufferOffset:0];
        */
    }

    void MetalRendererAPI::DrawLine(VertexArray& vertexarray, uint32_t count)
    {
        /* TO FIX
        vertexarray.Bind(s_CurrentEncoder);
        [MTL_ENC drawPrimitives:MTLPrimitiveTypeLine
                             vertexStart:0
                             vertexCount:count];
        */
    }
}