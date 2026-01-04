#pragma once

#include "Crimson/Core/Core.h"
#include "Crimson/Renderer/CubeMapReflection.h"
#include "Crimson/Mesh/LoadMesh.h"
#include "Crimson/Scene/Scene.h"

namespace Crimson {
	struct SubMesh;
	class Shadows;
	class Renderer3D
	{
	public:
		static void Init(int width = 1920, int height = 1080);
		static void BeginScene(OrthographicCamera& camera);
		//if the otherShader is nullptr then the renderer will use the default shaders for rendering
		static void BeginScene(Camera& camera, const Ref<Shader>& otherShader = nullptr);
		//if the otherShader is nullptr then the renderer will use the default shaders for rendering
		static void BeginSceneFoliage(Camera&, const Ref<Shader>& otherShader = nullptr);

		static void EndScene();
	public:



		// todo <----------------
		// need to make these drawing funtions take it const refrences 

		static void SetSunLightDirection(const glm::vec3& dir);
		static void SetSunLightColorAndIntensity(const glm::vec3& color, float Intensity);
		static void SetPointLightPosition(const std::vector<PointLight*>& Lights);
		static void DrawMesh(LoadMesh& mesh, const glm::vec3& Position, const glm::vec3& Scale = { 1,1,1 }, const glm::vec3& rotation = { 0,0,0 }, const glm::vec4& color = { 1,1,1,1 });//take the mesh class reference
		static void DrawMesh(LoadMesh& mesh, const glm::mat4& transform, const glm::vec4& color = { 1,1,1,1 }, bool wireframe = false, const float& material_Roughness = 1.0f, const float& material_metallic = 0.0f, Ref<Shader> otherShader = nullptr);//take the mesh class reference
		static void DrawFoliage(LoadMesh& mesh, glm::mat4& transform, const glm::vec4& color = { 1,1,1,1 }, const float& material_Roughness = 1.0f, const float& material_metallic = 0.0f);//take the mesh class reference
		static void DrawFoliageInstanced(const SubMesh& sub_mesh, glm::mat4& transform, uint32_t& indirectBufferID, float TimeElapsed = 0, bool applyGradientMask = false, bool enableWind = false);//take the mesh class reference
		static void AllocateInstancedFoliageData(LoadMesh& mesh, const size_t& size, uint32_t& buffIndex);
		static void InstancedFoliageData(LoadMesh& mesh, uint32_t& buffIndex);
		static void SetUpCubeMapReflections(Scene& scene);
		static void RenderShadows(Scene& scene, Camera& camera);
		static void AmbiantOcclusion(Scene& scene, Camera& camera);
		static void RenderWithAntialiasing();
		static void SetTransperancy(float val);
		static Ref<Shader>& GetFoliageInstancedShader();
		static Ref<Shadows>& GetShadowObj();
		static void RenderScene_Deferred(Scene* scene);
		static void ForwardRenderPass(Scene* scene, bool withWater);

	public:
		static uint32_t depth_id[4];
		static int index;
		static GPUHandle ssao_id;
		static glm::vec3 m_SunLightDir;
		static glm::vec3 m_SunColor;
		static float m_SunIntensity;
		static glm::mat4 m_oldProjectionView;
	private:
		static glm::vec3 m_oldSunLightDir;
		friend class LoadMesh;
	};
}
