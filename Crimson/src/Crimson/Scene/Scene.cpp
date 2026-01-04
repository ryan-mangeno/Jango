#include "cnpch.h"
#include "Scene.h"
#include "glm/gtc/matrix_transform.hpp"
#include "glm/gtx/transform.hpp"
#include "glm/gtx/quaternion.hpp"
#include "Entity.h"
#include "Component.h"
#include "Crimson/Renderer/Renderer2D.h"
#include "Crimson/Renderer/Renderer3D.h"
#include "Crimson/Renderer/Cameras/EditorCamera.h"
#include "glad/glad.h"
#include "Crimson/Mesh/LoadMesh.h"
#include "PointLight.h"
#include "Crimson/Physics/Physics3D.h"
#include "Crimson/Scene/SceneSerializer.h"
#include "Crimson/Renderer/Atmosphere.h"
#include "Crimson/Renderer/SkyRenderer.h"
#include "Crimson/Renderer/Terrain.h"
#include "Crimson/Renderer/Fog.h"
#include "Crimson/Renderer/Material.h"
#include "Crimson/RayTracer/RayTracer.h"

namespace Crimson {
	bool Scene::TOGGLE_SHADOWS = true;
	bool Scene::TOGGLE_SSAO = true;
	float Scene::foliage_dist = 3000.f;
	float Scene::num_foliage = 100.f;
	EditorCamera editor_cam;


	// i need to make these shared ptrs and make these specific to the scene not at the global scope, they
	// are static as of now, but should allow the ability to reset scenes, change scenes, etc

	LoadMesh* Scene::Sphere = nullptr,  * Scene::Sphere_simple = nullptr, * Scene::Cube     = nullptr, * Scene::Plane  = nullptr
		,	* Scene::plant  = nullptr , * Scene::House         = nullptr, * Scene::Windmill = nullptr, * Scene::Fern   = nullptr,
			* Scene::Sponza = nullptr,  * Scene::Grass         = nullptr, * Scene::Grass2   = nullptr, * Scene::Grass3 = nullptr, * Scene::GroundPlant = nullptr,
			* Scene::Tree1  = nullptr,  * Scene::Tree2         = nullptr, * Scene::Tree3    = nullptr, * Scene::Tree4  = nullptr, * Scene::Tree5       = nullptr,
			* Scene::Bush1  = nullptr,  * Scene::Bush2         = nullptr, * Scene::Rock1    = nullptr, * Scene::Rock2  = nullptr, * Scene::Flower1     = nullptr, * Scene::Flower2 = nullptr,
			* Scene::Freddy = nullptr;
		
	 bool capture = false;
	 glm::vec3 camloc = { 0.f,0.f,0.f }, camrot = {0.f,0.f,0.f};



	Scene::Scene()
	{
		CN_CORE_TRACE("Creating Scene Frame Buffer");
		framebuffer = FrameBuffer::Create({ 2048,2048 });
		CN_CORE_INFO("--- Scene Frame Buffer Created ---");

		CN_CORE_TRACE("Initializing Physx");
		Physics3D::Initialize();
		CN_CORE_INFO("--- Phsyx Initialized ---");

		SkyRenderer::SetSkyType(SkyType::PROCEDURAL_SKY);

		CN_CORE_TRACE("Initializng SkyRenderer");
		SkyRenderer::Initilize("Crimson_Editor/Assets/Textures/HDR/dusk.hdr");
		CN_CORE_INFO("--- SkyRender Initialized ---");

		CN_CORE_TRACE("Initializng 2D and 3D Renderer");
		Renderer3D::Init(1920,1080);
		Renderer2D::Init();
		CN_CORE_INFO("--- Renderers Initialized ---");

		CN_CORE_TRACE("Loading Materials...");
		Material::DeserializeMaterial();// load all materials from the disc
		CN_CORE_INFO("--- Materials Loaded ---");


		// intializing default camera to editor camera
		MainCamera = &editor_cam;

		//Trees
		Tree1 = new LoadMesh("Assets/Meshes/tree7.fbx");
		//Tree1 = new LoadMesh("Assets/Meshes/forest_PineTree1.fbx");
		Tree1->CreateLOD("Assets/Meshes/forest_PineTree1_LOD1.fbx");
		Tree2 = new LoadMesh("Assets/Meshes/forest_PineTree2.fbx");
		Tree2->CreateLOD("Assets/Meshes/forest_PineTree2_LOD1.fbx");
		Tree3 = new LoadMesh("Assets/Meshes/forest_PineTree3.fbx");
		Tree3->CreateLOD("Assets/Meshes/forest_PineTree3_LOD1.fbx");
		Tree4 = new LoadMesh("Assets/Meshes/forest_Tree.fbx");
		Tree4->CreateLOD("Assets/Meshes/forest_Tree_LOD1.fbx");
		Tree5 = new LoadMesh("Assets/Meshes/forest_Tree2.fbx");
		Tree5->CreateLOD("Assets/Meshes/forest_Tree2_LOD1.fbx");
		
		//Bushes
		Bush1 = new LoadMesh("Assets/Meshes/forest_Bush1.fbx");
		Bush1->CreateLOD("Assets/Meshes/forest_Bush1_LOD1.fbx");
		Bush2 = new LoadMesh("Assets/Meshes/forest_Bush2.fbx");
		Bush2->CreateLOD("Assets/Meshes/forest_Bush2_LOD1.fbx");
		
		//Rock
		Rock1 = new LoadMesh("Assets/Meshes/forest_rock1.fbx");
		Rock2 = new LoadMesh("Assets/Meshes/forest_rock2.fbx");
		Rock2->CreateLOD("Assets/Meshes/forest_rock2_LOD1.fbx");
		
		//Folliage
		Grass = new LoadMesh("Assets/Meshes/forest_grass.fbx");
		Grass2 = new LoadMesh("Assets/Meshes/forest_grass2.fbx");
		Grass2->CreateLOD("Assets/Meshes/forest_grass2_LOD1.fbx");
		Grass3 = new LoadMesh("Assets/Meshes/forest_grass3.fbx");
		Flower1 = new LoadMesh("Assets/Meshes/forest_flower1.fbx");
		Flower2 = new LoadMesh("Assets/Meshes/forest_flower2.fbx");
		Grass->CreateLOD("Assets/Meshes/grass3_LOD1.fbx");
		plant = new LoadMesh("Assets/Meshes/dragon.fbx");
		Fern = new LoadMesh("Assets/Meshes/forest_Fern.fbx");
		Fern->CreateLOD("Assets/Meshes/Fern_LOD1.fbx");
		GroundPlant = new LoadMesh("Assets/Meshes/forest_grass1.fbx");
		GroundPlant->CreateLOD("Assets/Meshes/flower_LOD1.fbx");

		// Objects
		Sphere = new LoadMesh("Assets/Meshes/Sphere.fbx");
		Sphere_simple = new LoadMesh("Assets/Meshes/sphere_simple.fbx");
		Plane = new LoadMesh("Assets/Meshes/Plane.fbx");
		Cube = new LoadMesh("Assets/Meshes/Cube.fbx");
		Freddy = new LoadMesh("Assets/Meshes/steve.fbx");
		House = new LoadMesh("Assets/Meshes/house.fbx");
		Windmill = new LoadMesh("Assets/Meshes/Windmill.fbx");
		Sponza = new LoadMesh("Assets/Meshes/Sponza.fbx");

		// Cube map setup
		Renderer3D::SetUpCubeMapReflections(*this);

		// camera settings
		editor_cam.SetVerticalFOV(45.f);
		editor_cam.SetPerspectiveFar(10000.f);
		editor_cam.SetViewportSize(1920.f/1080.f);

		// terrain creation
		m_Terrain = std::make_shared<Terrain>(2048.f,2048.f);

		//initilize Bloom
		m_Bloom = Bloom::Create();
		m_Bloom->GetFinalImage(0, { 1920.f,1080.f });
		m_Bloom->InitBloom();

		// creating fog
		m_Fog = Fog::Create(fogDensity,30.f, 5000.f, 100.f,10.f, { 1920.f,1080.f });

		// making ray tracer
		m_rayTracer = std::make_shared<RayTracer>();
	}


	Scene::~Scene()
	{
		delete Tree1;
		delete Tree2;
		delete Tree3;
		delete Tree4;
		delete Tree5;

		delete Bush1;
		delete Bush2;

		delete Rock1;
		delete Rock2;

		delete Grass;
		delete Grass2;
		delete Grass3;
		delete Flower1;
		delete Flower2;
		delete plant;
		delete Fern;
		delete GroundPlant;

		delete Sphere;
		delete Sphere_simple;
		delete Plane;
		delete Cube;
		delete Freddy;
		delete House;
		delete Windmill;
		delete Sponza;

		while (!m_PointLights.empty())
		{
			delete m_PointLights.back();
			m_PointLights.pop_back();
		}

		while (!entity_ptrs.empty())
		{

			// i also need to go through the components of the entites and delete those
			entt::entity& reg_entity = entity_ptrs.back()->GetEntity();
			m_registry.destroy(reg_entity);

			delete entity_ptrs.back();
			entity_ptrs.pop_back();
		}
	}



	Entity* Scene::CreateEntity(const std::string& name, const glm::vec3& position)
	{
		m_entity = m_registry.create();
		Entity* entity = new Entity(this, m_entity);
		entity_ptrs.push_back(entity);

		// spawn entity at player
		entity->AddComponent<TransformComponent>(MainCamera->GetCameraPosition());
		entity->AddComponent<StaticMeshComponent>(Cube);

		if (name == "")//if no name is give to an entity just call it entity (i.e define tag with entity)
			entity->AddComponent<TagComponent>("Entity");//automatically add a tag component when an entity is created
		else
			entity->AddComponent<TagComponent>(name);
		//Entity_Map[entity->GetComponent<TagComponent>()] = entity;
		capture = true;
		return entity;
	}
	void Scene::DestroyEntity(const Entity& delete_entity)
	{
		m_registry.destroy(delete_entity);
	}
	void Scene::OnUpdate(TimeStep ts)
	{

		// to see if main camera changed to entity, else we default back to editor camera
		bool cam_changed = false;

		m_Fog->SetFogParameters(fogDensity, fogTop, fogEnd, fogColor);

		//update camera , Mesh Forward vectors....
		const auto& view = m_registry.view<CameraComponent>();

		for (auto& entt : view) {

			CameraComponent& camera = m_registry.get<CameraComponent>(entt);

			if (camera.camera.bIsMainCamera) {

				MainCamera = &camera.camera;
				cam_changed = true;

				TransformComponent& tc = m_registry.get<TransformComponent>(entt);
				glm::mat4 transform = tc.GetTransform();

				if (camera.bFollowPlayer)
				{
					glm::vec3& rotation = tc.Rotation;
					glm::vec3 cam_pos = MainCamera->GetCameraPosition();

					tc.RightVector = glm::cross(tc.ForwardVector, tc.UpVector);
					tc.ForwardVector = glm::mat3(glm::rotate(glm::radians(rotation.y), tc.UpVector)) * glm::mat3(glm::rotate(glm::radians(rotation.x), tc.RightVector)) * glm::vec3(0, 0, 1);
					MainCamera->SetViewDirection(tc.ForwardVector);// Make the view direction of the camera same as the mesh forward direction

					float dist = glm::length(camera.camera_dist);//scale the -forward vector with the radius of the circle
					glm::vec3 object_pos = glm::vec3(transform[3][0], transform[3][1], transform[3][2]);
					tc.ForwardVector = -glm::normalize(tc.ForwardVector);
					MainCamera->SetCameraPosition(tc.ForwardVector * dist + object_pos-camera.camera_dist);//align the camera with the mesh view vector
				}
				break;
			}
		}

		if (!cam_changed)
		{
			MainCamera = &editor_cam;
		}

		MainCamera->OnUpdate(ts);

		//run scripts
		m_registry.view<ScriptComponent>().each([=](entt::entity entity, ScriptComponent& nsc) 
		{
				if(nsc.m_Script==nullptr)
				nsc.CreateInstance();// this needs to be done once ,not every frame.
			
				m_registry.each([&](auto m_entity)//iterate through all entities
					{
						if (entity == m_entity)
						{
							nsc.m_Script->m_Entity = new Entity(this, m_entity);//the Entity in the script class is made equal to the created scene entity
							entity_ptrs.push_back(nsc.m_Script->m_Entity);
						}
					});
			nsc.m_Script->OnUpdate(ts);//update to get the script values
			});
		
		if (m_PointLights.size() > 0)
			Renderer3D::SetPointLightPosition(m_PointLights);

		/*
		* Physx debugging
		* 
		* 
		Renderer2D::BeginScene(*MainCamera);
		for (int i = 0; i < Physics3D::DebugPoints.size(); i++)
		{
			Renderer2D::DrawLine(Physics3D::DebugPoints[i].pos0, Physics3D::DebugPoints[i].pos1, glm::vec4(0.0, 1.0, 0.6, 1.0));
		}
		*/
		Renderer3D::SetSunLightDirection(Renderer3D::m_SunLightDir);
		Renderer3D::SetSunLightColorAndIntensity(Renderer3D::m_SunColor, Renderer3D::m_SunIntensity);
		

		// to work on
		//m_rayTracer->RenderImage(*MainCamera);
	}
	void Scene::OnCreate()
	{
	}
	void Scene::Resize(float Width, float Height)
	{
		const auto& view = m_registry.view<CameraComponent>();
		for (auto& entity : view) {
			SceneCamera& camera = m_registry.get<CameraComponent>(entity).camera;
			if(camera.IsResiziable && camera.IsResiziable)
				m_registry.get<CameraComponent>(entity).camera.SetViewportSize(Width/Height);
		}
		MainCamera->SetViewportSize(Width/ Height);//resize the editor camera
	}
	void Scene::OnEvent(Event& e)
	{
		MainCamera->OnEvent(e);

		// auto deduces to std::pair of type {size_t, ScriptableEntity*}
		for (auto& s : m_scriptsMap)
		{
			s.second->OnEvent(e);
		}
	}

	void Scene::PostProcess()
	{
		Atmosphere::RenderAtmosphere(*MainCamera, 200.0f);
	}

	void Scene::AddPointLight(PointLight* light)
	{
		m_PointLights.push_back(light);
	}

	Ref<Scene> Scene::Create()
	{
		return std::make_shared<Scene>();
	}
}
