#pragma once
#include "Crimson.h"

namespace Crimson {
	class EditorCamera;
	class Shadows {
	public:
		Shadows();
		Shadows(float width, float height);
		virtual ~Shadows();
		virtual void RenderShadows(Scene& scene, const glm::vec3& LightPosition , Camera& cam) = 0;
		virtual void RenderTerrainShadows(Scene& scene, const glm::vec3& LightPosition, Camera& cam) =0;
		virtual void RenderFoliageShadows(LoadMesh* mesh, uint32_t bufferID, int numMeshes, const glm::vec3& LightPosition, Camera& cam) = 0;

		virtual void PassShadowUniforms(Camera& cam, Ref<Shader> rendering_shader) = 0;
		virtual void SetShadowMapResolution(const float& width, float height) = 0;
		virtual uint32_t GetDepth_ID(int index) = 0;
		static Ref<Shadows> Create(float width, float height);
		static Ref<Shadows> Create();//creates a texture map of 2048x2048 resolution
	public:
		std::vector<float> Ranges;
		static int Cascade_level;
		static float m_lamda;
	};
}