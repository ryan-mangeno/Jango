#pragma once
#include "Crimson/Renderer/FrameBuffer.h"
#include "Crimson/Renderer/Shader.h"
#include "Crimson/Scene/Scene.h"
#include "MetalTexture2D.h"

namespace Crimson {

    class MetalDeferredRenderer
    {
    public:
        static void Init(int width, int height);
        static void CreateBuffers(Scene* scene, bool withWater);
        static void DeferredPass();
        
        static Ref<Shader> GetDeferredShader() { return m_DefferedPassShader; }
        
        static uintptr_t GetBuffers(uint32_t bufferInd);

    private:
        static void RenderEntities(Scene* scene);

        static Ref<FrameBuffer> m_GBuffer;
        static Ref<Shader> m_ForwardPassShader;
        static Ref<Shader> m_DefferedPassShader;

        static Ref<MetalTexture2D> m_NormalTexture;
        static Ref<MetalTexture2D> m_VelocityTexture;
        static Ref<MetalTexture2D> m_AlbedoTexture;
        static Ref<MetalTexture2D> m_RoughnessTexture;
        static Ref<MetalTexture2D> m_DepthTexture;

        static int m_Width, m_Height;
        
    };
}