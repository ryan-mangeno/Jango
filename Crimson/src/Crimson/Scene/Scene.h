#pragma once
#include "entt.hpp"
#include "Crimson/Core/Log.h"
#include "Crimson/Renderer/FrameBuffer.h"
#include "Crimson/Events/Event.h"
#include "Crimson/Core/TimeStep.h"
#include "Crimson/Renderer/Cameras/Camera.h"
#include "Crimson/Core/Core.h"

namespace Crimson {

	class Entity;
	class LoadMesh;
	class ScriptableEntity;
	class EditorCamera;
	class Camera;
	class PointLight;
	class Bloom;
	class Fog;
	class Terrain;
	class RayTracer;

	class Scene
	{
		public:
			static bool TOGGLE_SHADOWS;//universal switch to enable or disable shadows
			static bool TOGGLE_SSAO;////universal switch to enable or disable ssao
		public:
			Scene();
			~Scene();
			entt::registry& getRegistry() { return m_registry; }
			Entity* CreateEntity(const std::string& name = "Entity", const glm::vec3& position = { 0.0f, 0.0f, 0.0f });
			void DestroyEntity(const Entity& delete_entity);
			//const entt::registry& GetRegistry() { return m_registry; }
			void OnUpdate(TimeStep ts);
			void OnCreate();
			void Resize(float Width, float Height);
			void OnEvent(Event& e);
			void AddPointLight(PointLight* light);
			static Ref<Scene> Create();
			void PostProcess();
			Camera* GetCamera() { return MainCamera; }

		public:
			std::vector<PointLight*> m_PointLights;
			static LoadMesh* Sphere, * Sphere_simple, * Cube, * Plane, * plant, * House, * Windmill, * Sponza, * Flower,
				* Fern, * Grass, * Grass2, * Grass3, * GroundPlant,
				* Tree, * Tree1, * Tree2, * Tree3, * Tree4, * Tree5, * TreeDead,
				* Bush1, * Bush2, * Rock1, * Rock2, * Flower1, * Flower2,
				* Freddy;
			static uint32_t m_Scene_tex_id;
			static uint32_t m_Scene_depth_id;
			Ref<FrameBuffer> framebuffer;
			std::unordered_map<size_t, ScriptableEntity*> m_scriptsMap;
			static float foliage_dist, num_foliage;
			Ref<Bloom> m_Bloom;
			Ref<Fog> m_Fog;
			float fogDensity=0.00002, fogTop=100, fogEnd=300;
			glm::vec3 fogColor = glm::vec3(1,1,1);
			Ref<Terrain> m_Terrain;
			Ref<RayTracer> m_rayTracer;
		private:
			Camera* MainCamera = nullptr;//if there is no main camera Then dont render
			entt::registry m_registry;
			entt::entity m_entity{entt::null};
			std::thread shadow_thread;
			std::vector<Entity*> entity_ptrs;
			//friend class Entity;

	};
}

