#pragma once

#include "Crimson/Renderer/Buffer.h"
#include "Crimson/Renderer/Shader.h"
#include "Crimson/Renderer/RenderCommand.h"
#include "Crimson/Renderer/Texture.h"
#include "Crimson/Renderer/FrameBuffer.h"

namespace Crimson {

    class CubeMapEnvironment {
    public:
        static void Init(const std::string& path);
        static void RenderCubeMap(const glm::mat4& view, const glm::mat4& proj, const glm::vec3& view_dir);
        
        static void RenderQuad(const glm::mat4& view, const glm::mat4& proj);
        static void RenderQuad(); 

    private:
		static void SwitchToFace(int n, float& pitch, float& yaw);
        static void RenderUnitCube(); 
        static void ConstructIrradianceMap(const glm::mat4& proj);
        static void CreateSpecularMap(const glm::mat4& proj, glm::mat4* viewDirs);

    private:
        static Ref<TextureCube> m_EnvironmentMap;
        static Ref<TextureCube> m_IrradianceMap;
        static Ref<TextureCube> m_PrefilterMap;
        static Ref<Texture2D> m_BRDFLUT;
        
        static Ref<FrameBuffer> m_CaptureFramebuffer;
        static Ref<VertexArray> m_CubeVAO;

        static uint32_t captureRes;
        
        static Ref<Shader> Cube_Shader;
        static Ref<Shader> equirectangularToCube_shader;
        static Ref<Shader> irradiance_shader;
        static Ref<Shader> prefilterShader;
        static Ref<Shader> BRDFSumShader;
    };
}