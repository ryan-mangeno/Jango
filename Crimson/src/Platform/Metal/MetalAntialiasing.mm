#include "cnpch.h"

#include "MetalAntialiasing.h"
#include "MetalContext.h"
#include "MetalRendererAPI.h"

#import <Metal/Metal.h>
#import <QuartzCore/CAMetalLayer.h>

namespace Crimson
{
    struct MetalData {
        id<MTLTexture> currentTexture = nil;
        id<MTLTexture> historyTexture = nil;
        id<MTLRenderPipelineState> pipelineState = nil;
        id<MTLDevice> device = nil;
    };

    MetalAntialiasing::MetalAntialiasing(int width, int height)
    {
        // alloc internal metal data container
        m_MetalData = new MetalData();
        Init(width, height);
    }

    MetalAntialiasing::~MetalAntialiasing()
    {
        delete (MetalData*)m_MetalData;
    }

    void MetalAntialiasing::Init(int width, int height)
    {
        CN_PROFILE_FUNCTION();

        m_Width = width;
        m_Height = height;

        MetalData* data = (MetalData*)m_MetalData;
        data->device = (__bridge id<MTLDevice>)MetalRendererAPI::GetDevice();

        MTLTextureDescriptor* desc = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA16Float
                                                                                        width:width
                                                                                       height:height
                                                                                    mipmapped:NO];
        desc.usage = MTLTextureUsageRenderTarget | MTLTextureUsageShaderRead;

        data->currentTexture = [data->device newTextureWithDescriptor:desc];
        data->historyTexture = [data->device newTextureWithDescriptor:desc];

        // need to create 'TAA.metal' in Assets/Shaders/{API}/ with "vertex_taa" and "fragment_taa"
        id<MTLLibrary> library = [data->device newDefaultLibrary];
        if (!library) {
            CN_CORE_ERROR("Metal: Failed to load default library. Missing .metal files?");
            return;
        }

        MTLRenderPipelineDescriptor* pipelineDesc = [[MTLRenderPipelineDescriptor alloc] init];
        pipelineDesc.vertexFunction = [library newFunctionWithName:@"vertex_taa"];
        pipelineDesc.fragmentFunction = [library newFunctionWithName:@"fragment_taa"];
        pipelineDesc.colorAttachments[0].pixelFormat = MTLPixelFormatRGBA16Float; // writing to currentTexture

        NSError* error = nil;
        data->pipelineState = [data->device newRenderPipelineStateWithDescriptor:pipelineDesc error:&error];
        
        if (error) {
            CN_CORE_ERROR("Metal TAA Pipeline Error: {0}", [[error localizedDescription] UTF8String]);
        }
    }

    void MetalAntialiasing::Update()
    {
        CN_PROFILE_FUNCTION();

        MetalData* data = (MetalData*)m_MetalData;
        m_num_frame++;

        // resize Check
        glm::vec2 screenSize = RenderCommand::GetViewportSize();
        if (m_Width != (int)screenSize.x || m_Height != (int)screenSize.y)
        {
            Init((int)screenSize.x, (int)screenSize.y);
        }

        id<MTLCommandQueue> queue = (__bridge id<MTLCommandQueue>)MetalRendererAPI::GetCommandQueue();
        id<MTLCommandBuffer> commandBuffer = [queue commandBuffer];
        commandBuffer.label = @"TAA Pass";

        MTLRenderPassDescriptor* passDesc = [MTLRenderPassDescriptor renderPassDescriptor];
        passDesc.colorAttachments[0].texture = data->currentTexture;
        passDesc.colorAttachments[0].loadAction = MTLLoadActionClear;
        passDesc.colorAttachments[0].storeAction = MTLStoreActionStore;
        passDesc.colorAttachments[0].clearColor = MTLClearColorMake(0, 0, 0, 1);

        // encoding render cmd
        id<MTLRenderCommandEncoder> encoder = [commandBuffer renderCommandEncoderWithDescriptor:passDesc];
        [encoder setRenderPipelineState:data->pipelineState];

        // In Metal, you must pass the texture objects , need to fetch these from Renderer
        
        // Slot 0: History (Previous Frame)
        [encoder setFragmentTexture:data->historyTexture atIndex:0]; 
        
        // Slot 1: Current Scene (Raw, Aliased)
        // [encoder setFragmentTexture: GetSceneTexture() atIndex:1]; 
        
        // Slot 2: Depth
        // [encoder setFragmentTexture: GetDepthTexture() atIndex:2];

        // Slot 3: Velocity
        // [encoder setFragmentTexture: GetVelocityTexture() atIndex:3];

        // Draw Full Screen Quad (Vertexless)
        [encoder drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:3];
        [encoder endEncoding];

        // Blit (Copy) Current -> History for next frame
        id<MTLBlitCommandEncoder> blit = [commandBuffer blitCommandEncoder];
        [blit copyFromTexture:data->currentTexture 
                  sourceSlice:0 sourceLevel:0 sourceOrigin:MTLOriginMake(0, 0, 0) 
                   sourceSize:MTLSizeMake(m_Width, m_Height, 1) 
                    toTexture:data->historyTexture 
             destinationSlice:0 destinationLevel:0 destinationOrigin:MTLOriginMake(0, 0, 0)];
        [blit endEncoding];

        // [commandBuffer commit];
        // commit once at the end of main render loop
    }

    void MetalAntialiasing::RenderQuad()
    {
        // In Metal, we dont need a specific function to create VAOs like OpenGL
        // The draw is handled inside Update() using drawPrimitives with vertex_id
    }
}