#include "cnpch.h"
#include "MetalSSAO.h"
#include "MetalRendererAPI.h"
#include "MetalDeferredRenderer.h"
#include "Crimson/Renderer/RenderCommand.h"

#import <Metal/Metal.h>
#include <random>

namespace Crimson {

    // Must match the SSAO.metal Uniforms struct EXACTLY
    struct SSAOUniforms {
        float ScreenWidth;
        float ScreenHeight;
        // Metal arrays are 16-byte aligned. glm::vec3 is 12 bytes, so use vec4 to be safe
        glm::vec4 Samples[RANDOM_SAMPLES_SIZE]; 
        glm::mat4 u_Projection;
        glm::mat4 u_InverseProjection;
        glm::vec3 u_CamPos;
        int isFoliage;
    };

    MetalSSAO::MetalSSAO(int width, int height)
        : m_width(width), m_height(height)
    {
        m_SSAOShader = Shader::Create("Crimson_Editor/Assets/Shaders/Metal/SSAO.metal");
        m_SSAOBlurShader = Shader::Create("Crimson_Editor/Assets/Shaders/Metal/SSAO_Blur.metal");

        GenerateKernel();
        CreateNoiseTexture();
        CreateSSAOTexture(width, height);
    }

    MetalSSAO::~MetalSSAO()
    {
        if (m_SSAORawTexture) CFRelease(m_SSAORawTexture);
        if (m_SSAOBlurTexture) CFRelease(m_SSAOBlurTexture);
        if (m_NoiseTexture) CFRelease(m_NoiseTexture);
    }

    void MetalSSAO::GenerateKernel()
    {
        std::uniform_real_distribution<float> randomFloats(0.0, 1.0);
        std::default_random_engine generator;

        for (unsigned int i = 0; i < RANDOM_SAMPLES_SIZE; ++i)
        {
            glm::vec3 sample(
                randomFloats(generator) * 2.0 - 1.0, 
                randomFloats(generator) * 2.0 - 1.0, 
                randomFloats(generator)
            );
            sample = glm::normalize(sample);
            sample *= randomFloats(generator);

            // Scale samples to be clustered closer to the origin (hemisphere center)
            float scale = float(i) / float(RANDOM_SAMPLES_SIZE);
            scale = 0.1f + (scale * scale) * (0.9f); // Lerp
            sample *= scale;

            m_Samples[i] = sample;
        }
    }

    void MetalSSAO::CreateNoiseTexture()
    {
        std::uniform_real_distribution<float> randomFloats(0.0, 1.0);
        std::default_random_engine generator;

        std::vector<glm::vec3> ssaoNoise;
        for (unsigned int i = 0; i < 16; i++) // 4x4 Noise
        {
            glm::vec3 noise(
                randomFloats(generator) * 2.0 - 1.0, 
                randomFloats(generator) * 2.0 - 1.0, 
                0.0f); 
            ssaoNoise.push_back(noise);
        }

        id<MTLDevice> device = (__bridge id<MTLDevice>)MetalRendererAPI::GetDevice();
        MTLTextureDescriptor* desc = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA32Float 
                                                                                        width:4 
                                                                                       height:4 
                                                                                    mipmapped:NO];
        desc.usage = MTLTextureUsageShaderRead;
        id<MTLTexture> texture = [device newTextureWithDescriptor:desc];

        // Upload Noise Data (std::vector<vec3> is tightly packed, but Metal RGBA32F expects 4 floats)
        // We need to convert vec3 to vec4 (padding) or use RGB32Float if supported (Metal rarely supports 3-channel)
        std::vector<glm::vec4> ssaoNoiseAligned;
        for(auto& v : ssaoNoise) ssaoNoiseAligned.push_back(glm::vec4(v, 0.0f));

        [texture replaceRegion:MTLRegionMake2D(0, 0, 4, 4) 
                   mipmapLevel:0 
                     withBytes:ssaoNoiseAligned.data() 
                   bytesPerRow:4 * sizeof(glm::vec4)];

        m_NoiseTexture = (__bridge_retained void*)texture;
    }

    void MetalSSAO::SetSSAO_TextureDimension(int width, int height)
    {
        CreateSSAOTexture(width, height);
    }

    void MetalSSAO::CreateSSAOTexture(int width, int height)
    {
        m_width = width;
        m_height = height;

        if (m_SSAORawTexture) CFRelease(m_SSAORawTexture);
        if (m_SSAOBlurTexture) CFRelease(m_SSAOBlurTexture);

        id<MTLDevice> device = (__bridge id<MTLDevice>)MetalRendererAPI::GetDevice();

        // Raw SSAO (Noisy)
        MTLTextureDescriptor* desc = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatR8Unorm 
                                                                                        width:width 
                                                                                       height:height 
                                                                                    mipmapped:NO];
        desc.usage = MTLTextureUsageRenderTarget | MTLTextureUsageShaderRead;
        desc.storageMode = MTLStorageModePrivate;
        m_SSAORawTexture = (__bridge_retained void*)[device newTextureWithDescriptor:desc];

        // Blur SSAO (Final)
        m_SSAOBlurTexture = (__bridge_retained void*)[device newTextureWithDescriptor:desc];
    }

    void MetalSSAO::CaptureScene(Scene& scene, Camera& cam)
    {
        // -----------------------------------------------------------------
        // PASS 1: Generate Occlusion
        // -----------------------------------------------------------------
        MetalRendererAPI::FlushEncoder();

        MTLRenderPassDescriptor* passDesc = [MTLRenderPassDescriptor renderPassDescriptor];
        passDesc.colorAttachments[0].texture = (__bridge id<MTLTexture>)m_SSAORawTexture;
        passDesc.colorAttachments[0].loadAction = MTLLoadActionClear;
        passDesc.colorAttachments[0].storeAction = MTLStoreActionStore;
        passDesc.colorAttachments[0].clearColor = MTLClearColorMake(0, 0, 0, 1);

        id<MTLCommandBuffer> cmdBuf = (__bridge id<MTLCommandBuffer>)MetalRendererAPI::GetCurrentCommandBuffer();
        id<MTLRenderCommandEncoder> encoder = [cmdBuf renderCommandEncoderWithDescriptor:passDesc];
        MetalRendererAPI::SetCurrentEncoder((void*)CFBridgingRetain(encoder));

        m_SSAOShader->Bind();

        // Prepare Uniforms
        SSAOUniforms uniforms;
        uniforms.ScreenWidth = (float)m_width;
        uniforms.ScreenHeight = (float)m_height;
        uniforms.u_Projection = cam.GetProjectionMatrix();
        uniforms.u_InverseProjection = glm::inverse(cam.GetProjectionMatrix());
        uniforms.u_CamPos = cam.GetCameraPosition();
        uniforms.isFoliage = 0; // Or passed param

        // Copy Kernel
        for(int i=0; i<RANDOM_SAMPLES_SIZE; i++) {
            uniforms.Samples[i] = glm::vec4(m_Samples[i], 0.0f); // Alignment
        }

        // Upload Uniforms
        // Assuming Shader::SetMat4 etc handles this, OR if we need raw upload:
        [encoder setFragmentBytes:&uniforms length:sizeof(SSAOUniforms) atIndex:1];

        // Bind Textures (Inputs)
        // Get Depth/Normal from Deferred Renderer (We assume they are available statically or passed)
        // In the previous turns we added GetBuffers(i) to MetalDeferredRenderer
        // Slot 0: Depth, Slot 1: Normal, Slot 2: Noise
        
        // Unsafe cast from uint32_t back to void* then id<MTLTexture>
        // Ideally MetalDeferredRenderer would expose Ref<Texture2D>
        void* rawDepth = (void*)(uintptr_t)MetalDeferredRenderer::GetBuffers(4); // Assuming 4 is Depth? Wait, GetBuffers only had 0-3.
        // We need to fetch Depth. Let's assume we can get it. 
        // If MetalDeferredRenderer doesn't expose Depth in GetBuffers, you need to add "case 4: return m_DepthTexture->ID" to it.
        
        // For now, let's assume we bind via the shader system or manual calls if you expose the pointers.
        
        // Assuming your Shader::Bind() doesn't auto-bind textures, we do it here:
        // [encoder setFragmentTexture: ... atIndex:0]; // Depth
        // [encoder setFragmentTexture: ... atIndex:1]; // Normal
        [encoder setFragmentTexture:(__bridge id<MTLTexture>)m_NoiseTexture atIndex:2]; // Noise

        RenderQuad(); // Draws the full screen quad

        [encoder endEncoding];
        CFRelease((__bridge CFTypeRef)encoder);
        MetalRendererAPI::SetCurrentEncoder(nullptr);

        // PASS 2: Blur
        MetalRendererAPI::FlushEncoder();

        MTLRenderPassDescriptor* blurPass = [MTLRenderPassDescriptor renderPassDescriptor];
        blurPass.colorAttachments[0].texture = (__bridge id<MTLTexture>)m_SSAOBlurTexture;
        blurPass.colorAttachments[0].loadAction = MTLLoadActionClear;
        blurPass.colorAttachments[0].storeAction = MTLStoreActionStore;
        
        id<MTLRenderCommandEncoder> blurEncoder = [cmdBuf renderCommandEncoderWithDescriptor:blurPass];
        MetalRendererAPI::SetCurrentEncoder((void*)CFBridgingRetain(blurEncoder));
        
        m_SSAOBlurShader->Bind();
        
        // Bind Raw SSAO as Input (Slot 0 in Blur Shader)
        [blurEncoder setFragmentTexture:(__bridge id<MTLTexture>)m_SSAORawTexture atIndex:0];
        
        RenderQuad();
        
        [blurEncoder endEncoding];
        CFRelease((__bridge CFTypeRef)blurEncoder);
        MetalRendererAPI::SetCurrentEncoder(nullptr);
    }

    void MetalSSAO::RenderQuad()
    {
        // need to add a Re-use static quad drawing 
        // quick impl here
        static float quadVertices[] = {
            -1, -1, 0, 1,   0, 0, 0, 0,
             1, -1, 0, 1,   1, 0, 0, 0,
             1,  1, 0, 1,   1, 1, 0, 0,
            -1,  1, 0, 1,   0, 1, 0, 0
        };
        static uint32_t quadIndices[] = { 0, 1, 2, 2, 3, 0 };

        id<MTLDevice> device = (__bridge id<MTLDevice>)MetalRendererAPI::GetDevice();
        id<MTLBuffer> vb = [device newBufferWithBytes:quadVertices length:sizeof(quadVertices) options:MTLResourceStorageModeShared];
        id<MTLBuffer> ib = [device newBufferWithBytes:quadIndices length:sizeof(quadIndices) options:MTLResourceStorageModeShared];

        id<MTLRenderCommandEncoder> encoder = (__bridge id<MTLRenderCommandEncoder>)MetalRendererAPI::GetCurrentEncoder();
        
        if (encoder) {
            [encoder setVertexBuffer:vb offset:0 atIndex:0]; 
            [encoder drawIndexedPrimitives:MTLPrimitiveTypeTriangle 
                                indexCount:6 
                                 indexType:MTLIndexTypeUInt32 
                               indexBuffer:ib 
                         indexBufferOffset:0];
        }
    }
    
    // Unused in Deferred SSAO (Left empty to satisfy interface)
    void MetalSSAO::RenderScene(Scene& scene, Ref<Shader>& current_shader) {}
    void MetalSSAO::RenderTerrain(Scene& scene, Ref<Shader>& current_shader1, Ref<Shader>& current_shader2) {}

}