#pragma once

#include "Crimson/Renderer/SSAO.h"
#include "Crimson/Renderer/Shader.h"
#include "Crimson/Renderer/GPUHandle.h"
#include "MetalFrameBuffer.h" // Added

#include <vector>

#define RANDOM_SAMPLES_SIZE 64

namespace Crimson {

    class MetalSSAO : public SSAO
    {
    public:
        MetalSSAO(int width, int height);
        virtual ~MetalSSAO();

        virtual void SetSSAO_TextureDimension(int width, int height) override;
        virtual void CreateSSAOTexture(int width, int height) override;
        virtual void CaptureScene(Scene& scene, Camera& cam) override;
        
        virtual GPUHandle GetSSAOTextureHandle() override { 
            return m_Blur_FBO->GetSceneTextureHandle(); 
        }

    private:
        void GenerateKernel();
        void CreateNoiseTexture();
        void RenderQuad();

        void RenderScene(Scene& scene , Ref<Shader>& current_shader);
        void RenderTerrain(Scene& scene, Ref<Shader>& current_shader1, Ref<Shader>& current_shader2);

        int m_width, m_height;

        Ref<MetalFrameBuffer> m_SSAO_FBO;
        Ref<MetalFrameBuffer> m_Blur_FBO;
        
        void* m_NoiseTexture = nullptr; 

        Ref<Shader> m_SSAOShader;
        Ref<Shader> m_SSAOBlurShader;
        Ref<Shader> m_GBufferPositionInstanced;

        glm::vec3 m_Samples[RANDOM_SAMPLES_SIZE];
    };
}