#include "cnpch.h"
#include "MetalSSAO.h"

#include "Platform/Metal/MetalContext.h"
#include "Platform/Util/Util.h"
#include "Platform/Metal/MetalRendererAPI.h"
#include "Crimson/Renderer/Renderer3D.h" 

#import <Metal/Metal.h>
#include <random>
#include <glm/gtc/type_ptr.hpp>

namespace Crimson {

	inline id<MTLTexture> ToMetal(void* handle) { return (__bridge id<MTLTexture>)handle; }

    MetalSSAO::MetalSSAO(int width, int height)
    {
        CN_PROFILE_FUNCTION();

        // load shaders
        m_SSAOShader = Shader::Create("Crimson_Editor/Assets/Shaders/Metal/SSAO.metal");
        m_SSAOBlurShader = Shader::Create("Crimson_Editor/Assets/Shaders/Metal/SSAO_Blur.metal");

        // create textures & kernel
        CreateSSAOTexture(width, height);
    }

    MetalSSAO::~MetalSSAO()
    {
        // ARC handles cleanup
    }

    void MetalSSAO::SetSSAO_TextureDimension(int width, int height)
    {
        // Simply re create the textures at the new resolution
        CreateSSAOTexture(width, height);
    }

    void MetalSSAO::CreateSSAOTexture(int width, int height)
    {
        CN_PROFILE_FUNCTION();

        m_width = width;
        m_height = height;

        id<MTLDevice> device = (__bridge id<MTLDevice>)MetalRendererAPI::GetDevice();

        // create SSAO Raw Texture (R8Unorm)
        MTLTextureDescriptor* ssaoDesc = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatR8Unorm 
                                                                                            width:width 
                                                                                           height:height 
                                                                                        mipmapped:NO];
        ssaoDesc.usage = MTLTextureUsageRenderTarget | MTLTextureUsageShaderRead;
        m_SSAORawTexture = (__bridge_retained void*)[device newTextureWithDescriptor:ssaoDesc];

        // create SSAO Blur Texture (Output)
        m_SSAOBlurTexture = (__bridge_retained void*)[device newTextureWithDescriptor:ssaoDesc];

        // gen Kernel (Random Samples)
        std::uniform_real_distribution<float> RandomFloats(0.0f, 1.0f);
        std::default_random_engine generator;
        
        for (int i = 0; i < RANDOM_SAMPLES_SIZE; i++)
        {
            glm::vec3 sample(
                RandomFloats(generator) * 2.0f - 1.0f,
                RandomFloats(generator) * 2.0f - 1.0f,
                RandomFloats(generator)
            );
            sample = glm::normalize(sample);
            sample *= RandomFloats(generator);

            float scale = static_cast<float>(i) / RANDOM_SAMPLES_SIZE;
            float val = 0.1f * scale * scale + (1.0f - 0.1f) * scale * scale; // Lerp
            sample *= val;
            
            m_Samples[i] = sample;
        }

        // generate Noise Texture (4x4 Rotation Vectors)
        std::vector<glm::vec3> noiseData;
        for (int i = 0; i < 16; i++)
        {
            noiseData.push_back(glm::vec3(
                RandomFloats(generator) * 2.0f - 1.0f, 
                RandomFloats(generator) * 2.0f - 1.0f, 
                0.0f
            ));
        }

        MTLTextureDescriptor* noiseDesc = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA32Float 
                                                                                             width:4 
                                                                                            height:4 
                                                                                         mipmapped:NO];
        id<MTLTexture> noiseTex = [device newTextureWithDescriptor:noiseDesc];
        [noiseTex replaceRegion:MTLRegionMake2D(0, 0, 4, 4) 
                    mipmapLevel:0 
                      withBytes:noiseData.data() 
                    bytesPerRow:4 * sizeof(glm::vec3)]; // 12 or 16 bytes depending on padding? Metal usually expects 16 for float3/4
        
        // NOTE: glm::vec3 is 12 bytes, but Metal RGBA32Float expects 16 bytes per pixel
        // It's safer to use glm::vec4 for texture uploads to avoid alignment issues
        // For now, assuming handle packing, but keep this in mind if noise looks skewed
        
        m_NoiseTexture = (__bridge_retained void*)noiseTex;
    }

    void MetalSSAO::CaptureScene(Scene& scene, Camera& cam)
    {
        CN_PROFILE_FUNCTION();

        id<MTLCommandBuffer> cmdBuffer = (__bridge id<MTLCommandBuffer>)MetalRendererAPI::GetCurrentCommandBuffer();
        if (!cmdBuffer) return;

        // PASS 1: SSAO GENERATION (Raw)
        {
            MTLRenderPassDescriptor* pass = [MTLRenderPassDescriptor renderPassDescriptor];
            pass.colorAttachments[0].texture = ToMetal(m_SSAORawTexture);
            pass.colorAttachments[0].loadAction = MTLLoadActionClear;
            pass.colorAttachments[0].storeAction = MTLStoreActionStore;
            pass.colorAttachments[0].clearColor = MTLClearColorMake(0,0,0,1);

            id<MTLRenderCommandEncoder> encoder = [cmdBuffer renderCommandEncoderWithDescriptor:pass];
            encoder.label = @"SSAO Generation Pass";

            // Bind Pipeline
            m_SSAOShader->Bind(); 

            // Bind Textures
            // NOTE: You must retrieve the G-Buffer textures from Renderer3D or Scene
            // Since they are void*, we cast them using ToMetal()
            
            // Slot 0: G-Position
            // [encoder setFragmentTexture:ToMetal(Renderer3D::GetGPositionTexture()) atIndex:0]; 
            
            // Slot 1: G-Normal
            // [encoder setFragmentTexture:ToMetal(Renderer3D::GetGNormalTexture()) atIndex:1];

            // Slot 2: Noise
            [encoder setFragmentTexture:ToMetal(m_NoiseTexture) atIndex:2];
            
            // Slot 3: Depth (If needed by your shader logic)
            // [encoder setFragmentTexture:ToMetal(Renderer3D::GetDepthTexture()) atIndex:3];

            // Send Uniforms
            // MetalShader::Set* functions write to a CPU buffer, 
            // but for arrays/structs often cleaner to send bytes directly here for specialized passes.
            
            // Send Kernel Samples (Index 0 in Fragment Buffer)
            [encoder setFragmentBytes:m_Samples length:sizeof(m_Samples) atIndex:0];

            // Send Projection Matrix (Index 1 in Fragment Buffer)
            glm::mat4 proj = cam.GetProjectionMatrix();
            [encoder setFragmentBytes:&proj length:sizeof(glm::mat4) atIndex:1];

            // Send View Matrix (Index 2)
            glm::mat4 view = cam.GetViewMatrix();
            [encoder setFragmentBytes:&view length:sizeof(glm::mat4) atIndex:2];
            
            // Render Fullscreen Quad
            RenderQuad();

            [encoder endEncoding];
        }

        // PASS 2: SSAO BLUR
        {
            MTLRenderPassDescriptor* blurPass = [MTLRenderPassDescriptor renderPassDescriptor];
            blurPass.colorAttachments[0].texture = ToMetal(m_SSAOBlurTexture);
            blurPass.colorAttachments[0].loadAction = MTLLoadActionClear;
            blurPass.colorAttachments[0].storeAction = MTLStoreActionStore;

            id<MTLRenderCommandEncoder> encoder = [cmdBuffer renderCommandEncoderWithDescriptor:blurPass];
            encoder.label = @"SSAO Blur Pass";

            m_SSAOBlurShader->Bind();

            // Bind Raw SSAO as Input
            [encoder setFragmentTexture:ToMetal(m_SSAORawTexture) atIndex:0];

            RenderQuad();

            [encoder endEncoding];
        }
    }

    void MetalSSAO::RenderQuad()
    {
        // Vertex-less rendering: The shader generates coordinates from vertex_id
        id<MTLRenderCommandEncoder> encoder = (__bridge id<MTLRenderCommandEncoder>)MetalRendererAPI::GetCurrentEncoder();
        [encoder drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:3];
    }

    // Unused in this pass
    void MetalSSAO::RenderScene(Scene& scene, Ref<Shader>& current_shader) {}
    void MetalSSAO::RenderTerrain(Scene& scene, Ref<Shader>& current_shader1, Ref<Shader>& current_shader2) {}
}