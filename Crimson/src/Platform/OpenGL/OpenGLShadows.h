#pragma once
#include "Crimson.h"
#include "Crimson/Renderer/Shadows.h"
#include "Crimson/Mesh/LoadMesh.h"

#define MAX_CASCADES 4
namespace Crimson {
	class OpenGLShadows:public Shadows
	{
	public:
		OpenGLShadows();
		OpenGLShadows(const float& width, const float& height);
		~OpenGLShadows();
		void RenderShadows(Scene& scene, const glm::vec3& LightPosition, Camera& cam) override;
		void RenderTerrainShadows(Scene& scene, const glm::vec3& LightPosition, Camera& cam) override;
		void RenderFoliageShadows(LoadMesh* mesh, uint32_t bufferID, int numMeshes, const glm::vec3& LightPosition, Camera& cam) override;
		void SetShadowMapResolution(const float& width, float height) override;
		void PassShadowUniforms(Camera& cam, Ref<Shader> rendering_shader) override;
		virtual uint32_t GetDepth_ID(int index) override { return depth_id[index]; }
		void CreateShdowMap();
		
	private:
		void PrepareShadowProjectionMatrix(Camera& camera,const glm::vec3& LightPosition);

	private:
		uint32_t depth_id[MAX_CASCADES],framebuffer_id;//max 4 cascades
		float m_width, m_height;
		Ref<Shader> shadow_shader, terrain_shadowShader, shadow_shaderInstanced;
		std::vector<glm::mat4> m_ShadowProjection;
		glm::mat4 m_Camera_Projection;
		float m_ShadowAspectRatio = 1.0f;
		glm::mat4 LightView[MAX_CASCADES] = { glm::mat4(1.0f) };
		
		std::vector<int> n_cascades = { 0,1,2,3 };
	};
}