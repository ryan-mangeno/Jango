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

    void* MetalRendererAPI::s_Device = nullptr; // id<MTLDevice>
    void* MetalRendererAPI::s_CommandQueue = nullptr;; // id<MTLCommandQueue>
    void* MetalRendererAPI::s_CurrentEncoder = nullptr;; // id<MTLRenderCommandEncoder>
    void* MetalRendererAPI::s_CurrentCommandBuffer = nullptr; // id<MTLCommandBuffer>

    #define MTL_DEV   ((__bridge id<MTLDevice>)s_Device)
    #define MTL_QUEUE ((__bridge id<MTLCommandQueue>)s_CommandQueue)
    #define MTL_ENC   ((__bridge id<MTLRenderCommandEncoder>)s_CurrentEncoder)


    static void BindVertexBuffers(VertexArray& va, id<MTLRenderCommandEncoder> encoder) {
        const auto& buffers = va.GetVertexBuffers();
        for (uint32_t i = 0; i < buffers.size(); i++) {
            auto metalVB = std::dynamic_pointer_cast<MetalVertexBuffer>(buffers[i]);
            if (metalVB) {
                // ith buffer corresponds to [[buffer(i)]] in shader
                // might need an offset (i + 1) if buffer(0) becomes reserved for uniforms
                [encoder setVertexBuffer:(__bridge id<MTLBuffer>)metalVB->GetNativeBuffer()
                                  offset:0 
                                 atIndex:i]; 
            }
        }
    }

    MetalRendererAPI::MetalRendererAPI()
    {
    }

    MetalRendererAPI::~MetalRendererAPI()
    {
        if (s_Device) CFRelease(s_Device);
        s_Device = nullptr;

        if (s_CommandQueue) CFRelease(s_CommandQueue);
        s_CommandQueue = nullptr;

        // Encoder/CommandBuffer are transient, released in EndEncoding
    }

    void MetalRendererAPI::Init()
    {
        // get default device
        id<MTLDevice> mtlDevice = MTLCreateSystemDefaultDevice();
        s_Device = (void*)CFBridgingRetain(mtlDevice);

        id<MTLCommandQueue> cmdQ = [mtlDevice newCommandQueue];
        s_CommandQueue = (void*)CFBridgingRetain(cmdQ);

        id<MTLCommandBuffer> commandBuffer = [MTL_QUEUE commandBuffer];
        s_CurrentCommandBuffer = (void*)CFBridgingRetain(commandBuffer);

        CN_CORE_INFO("Metal Device: {0}", [[mtlDevice name] UTF8String]);

        // Depth Stencil State (Equivalent to glEnable(GL_DEPTH_TEST))
        MTLDepthStencilDescriptor *depthDesc = [[MTLDepthStencilDescriptor alloc] init];
        depthDesc.depthCompareFunction = MTLCompareFunctionLess; // GL_LESS
        depthDesc.depthWriteEnabled = YES;
        id<MTLDepthStencilState> depthSS = [mtlDevice newDepthStencilStateWithDescriptor:depthDesc];
        m_DepthStencilState = (void*)CFBridgingRetain(depthSS);
        
        // Note: Blending (glEnable(GL_BLEND)) is part of the PipelineState in Metal, 
        // not global state, configure blending in Shader/Material creation
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
        if (s_CurrentEncoder) EndEncoding();

        void* window = Application::Get().GetWindow().GetNativeWindow();
        GLFWwindow* glfwWindow = static_cast<GLFWwindow*>(window);
        NSWindow* nswin = glfwGetCocoaWindow(glfwWindow);

        if (!nswin) {
            CN_CORE_ERROR("Could not get Cocoa Window from GLFW!");
            return;
        }

        CAMetalLayer* metalLayer = (CAMetalLayer*)nswin.contentView.layer;
        id<CAMetalDrawable> drawable = [metalLayer nextDrawable];
        if (!drawable) {
            CN_CORE_ERROR("Could not get drawable!");
            return;
        }

        // setup the Render Pass (Clear Color, etc)
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

        s_CurrentCommandBuffer = (void*)CFBridgingRetain(commandBuffer);
        s_CurrentEncoder = (void*)CFBridgingRetain([commandBuffer renderCommandEncoderWithDescriptor:passDescriptor]);
        
        // reapply global states (Metal forgets these between passes)
        [MTL_ENC setDepthStencilState:(__bridge id<MTLDepthStencilState>)m_DepthStencilState];
        [MTL_ENC setFrontFacingWinding:MTLWindingCounterClockwise];
        [MTL_ENC setCullMode:MTLCullModeBack];
    }

    void MetalRendererAPI::EndEncoding()
    {
        if (s_CurrentEncoder) {
            [MTL_ENC endEncoding];
            CFRelease(s_CurrentEncoder);
            s_CurrentEncoder = nullptr;
        }
        if (s_CurrentCommandBuffer) {
            id<MTLCommandBuffer> cmdBuf = (__bridge id<MTLCommandBuffer>)s_CurrentCommandBuffer;
            [cmdBuf commit];
            CFRelease(s_CurrentCommandBuffer); // release bridge
            s_CurrentCommandBuffer = nullptr;
        }    
    }

    void MetalRendererAPI::DrawIndex(VertexArray& vertexarray, unsigned int renderingMode)
    {
       if (!s_CurrentEncoder) {
            CN_CORE_ERROR("No current encoder during DrawIndex!");
            return;
       }
        
        BindVertexBuffers(vertexarray, MTL_ENC);

        auto metalIB = std::dynamic_pointer_cast<MetalIndexBuffer>(vertexarray.GetIndexBuffer());
        if (!metalIB) {
            CN_CORE_ERROR("No index buffer during DrawIndex!");
            return;
        }

        // set Fill Mode                                            wireframe
        MTLTriangleFillMode fillMode = (renderingMode == CN_LINE) ? MTLTriangleFillModeLines : MTLTriangleFillModeFill;
        [MTL_ENC setTriangleFillMode:fillMode];

        // draw
        [MTL_ENC drawIndexedPrimitives:MTLPrimitiveTypeTriangle
                            indexCount:metalIB->GetCount()
                             indexType:MTLIndexTypeUInt32
                           indexBuffer:(__bridge id<MTLBuffer>)metalIB->GetNativeBuffer()
                     indexBufferOffset:0];
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