#pragma once

#include "Crimson/Renderer/SSAO.h"
#include "Crimson/Renderer/Shader.h"
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
        
        virtual void* GetSSAOTextureID() override { return m_SSAOBlurTexture; }

    private:
        void GenerateKernel();
        void CreateNoiseTexture();
        void RenderQuad();

        void RenderScene(Scene& scene , Ref<Shader>& current_shader);
		void RenderTerrain(Scene& scene, Ref<Shader>& current_shader1, Ref<Shader>& current_shader2);

        int m_width, m_height;

        void* m_GBufferPosTexture = nullptr;   // Type: id<MTLTexture> (RGBA16Float - World Positions)
        void* m_GBufferDepthTexture = nullptr; // Type: id<MTLTexture> (Depth32Float - Depth Buffer)
        void* m_SSAORawTexture = nullptr;      // Type: id<MTLTexture> (R8Unorm - Noisy Occlusion)
        void* m_SSAOBlurTexture = nullptr;     // Type: id<MTLTexture> (R8Unorm - Final Blurred Result)
        void* m_NoiseTexture = nullptr;        // Type: id<MTLTexture> (RGBA32Float - 4x4 Rotation Noise)

        Ref<Shader> m_SSAOShader;
        Ref<Shader> m_SSAOBlurShader;
        Ref<Shader> m_GBufferPositionInstanced;

        glm::vec3 m_Samples[RANDOM_SAMPLES_SIZE];
    };
}