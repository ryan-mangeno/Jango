#include "cnpch.h"
#include "MetalSSAO.h"
#include "MetalFrameBuffer.h"
#include "MetalRendererAPI.h"
#include "MetalDeferredRenderer.h"
#include "Crimson/Renderer/RenderCommand.h"

#import <Metal/Metal.h>
#include <random>

namespace Crimson {

    struct SSAOUniforms {
        float ScreenWidth;
        float ScreenHeight;
        glm::vec4 Samples[RANDOM_SAMPLES_SIZE]; 
        glm::mat4 u_Projection;
        glm::mat4 u_InverseProjection;
        glm::vec3 u_CamPos;
        int isFoliage;
    };

    static Ref<MetalFrameBuffer> m_SSAO_FBO;
    static Ref<MetalFrameBuffer> m_Blur_FBO;
    static void* m_NoiseTexture = nullptr;

    MetalSSAO::MetalSSAO(int width, int height)
        : m_width(width), m_height(height)
    {
        m_SSAOShader = Shader::Create("Crimson_Editor/Assets/Shaders/{API}/SSAO{EXT}");
        m_SSAOBlurShader = Shader::Create("Crimson_Editor/Assets/Shaders/{API}/SSAO_Blur{EXT}");

        GenerateKernel();
        CreateNoiseTexture();
        
        CreateSSAOTexture(width, height);
    }

    MetalSSAO::~MetalSSAO()
    {
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

            float scale = float(i) / float(RANDOM_SAMPLES_SIZE);
            scale = 0.1f + (scale * scale) * (0.9f); 
            sample *= scale;

            m_Samples[i] = sample;
        }
    }

    void MetalSSAO::CreateNoiseTexture()
    {
        std::uniform_real_distribution<float> randomFloats(0.0, 1.0);
        std::default_random_engine generator;

        std::vector<glm::vec3> ssaoNoise;
        for (unsigned int i = 0; i < 16; i++) 
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
        m_width = width;
        m_height = height;
        if (m_SSAO_FBO) m_SSAO_FBO->Resize(width, height);
        if (m_Blur_FBO) m_Blur_FBO->Resize(width, height);
    }

    void MetalSSAO::CreateSSAOTexture(int width, int height)
    {
        FrameBufferSpecification spec;
        spec.Width = width;
        spec.Height = height;

        m_SSAO_FBO = std::make_shared<MetalFrameBuffer>(spec);
        m_Blur_FBO = std::make_shared<MetalFrameBuffer>(spec);
    }

    void MetalSSAO::CaptureScene(Scene& scene, Camera& cam)
    {
        // Pass 1: Occlusion
        m_SSAO_FBO->Bind();
        m_SSAOShader->Bind();

        SSAOUniforms uniforms;
        uniforms.ScreenWidth = (float)m_width;
        uniforms.ScreenHeight = (float)m_height;
        uniforms.u_Projection = cam.GetProjectionMatrix();
        uniforms.u_InverseProjection = glm::inverse(cam.GetProjectionMatrix());
        uniforms.u_CamPos = cam.GetCameraPosition();
        uniforms.isFoliage = 0;

        for(int i=0; i<RANDOM_SAMPLES_SIZE; i++) {
            uniforms.Samples[i] = glm::vec4(m_Samples[i], 0.0f);
        }

        id<MTLRenderCommandEncoder> encoder = (__bridge id<MTLRenderCommandEncoder>)MetalRendererAPI::GetCurrentEncoder();
        [encoder setFragmentBytes:&uniforms length:sizeof(SSAOUniforms) atIndex:1];

        // Retrieve textures from G-Buffer
        void* depthTex  = (void*)(uintptr_t)MetalDeferredRenderer::GetBuffers(4); 
        void* normalTex = (void*)(uintptr_t)MetalDeferredRenderer::GetBuffers(0); 

        if (depthTex)  [encoder setFragmentTexture:(__bridge id<MTLTexture>)depthTex  atIndex:0];
        if (normalTex) [encoder setFragmentTexture:(__bridge id<MTLTexture>)normalTex atIndex:1];
        if (m_NoiseTexture) [encoder setFragmentTexture:(__bridge id<MTLTexture>)m_NoiseTexture atIndex:2];

        RenderQuad();

        m_SSAO_FBO->UnBind();

        // Pass 2: Blur
        m_Blur_FBO->Bind();
        m_SSAOBlurShader->Bind();
        
        m_SSAO_FBO->BindFramebufferTexture(0);
        
        RenderQuad();
        
        m_Blur_FBO->UnBind();
    }

    void MetalSSAO::RenderQuad()
    {
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
    
    void MetalSSAO::RenderScene(Scene& scene, Ref<Shader>& current_shader) {}
    void MetalSSAO::RenderTerrain(Scene& scene, Ref<Shader>& current_shader1, Ref<Shader>& current_shader2) {}

}