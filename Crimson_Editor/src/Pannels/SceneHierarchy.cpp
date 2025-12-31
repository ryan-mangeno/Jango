#include "SceneHierarchy.h"
#include "glm/gtc/type_ptr.hpp"
#include "imgui_internal.h"
#include "imgui.h"
#include "Crimson/Scene/PointLight.h"
#include "Crimson/Physics/Physics3D.h"
#include "Crimson/Scene/SceneSerializer.h"
#include "Crimson/Renderer/Material.h"
#include "../CustomScript.h"
#include "Crimson/Core/ResourceManager.h"

using namespace Crimson;
std::string texture_path = "Assets/Textures/Test.png";
Ref<Entity> SceneHierarchyPannel::m_selected_entity;
SceneHierarchyPannel::SceneHierarchyPannel() = default;
SceneHierarchyPannel::~SceneHierarchyPannel()
{
	delete m_selected_Light;
	delete m_Context->m_scriptsMap[typeid(CustomScript).hash_code()];
}

static void DrawVec3Control(const std::string& label, glm::vec3& values, float resetValue = 0.0f, float columnWidth = 100.0f ,char *x ="X",char *y="Y",char *z="Z")
{
	ImGui::PushID(label.c_str());

	ImGui::Columns(2);
	ImGui::SetColumnWidth(0, columnWidth);
	ImGui::Text(label.c_str());
	ImGui::NextColumn();

	ImGui::PushMultiItemsWidths(3, ImGui::CalcItemWidth());
	ImGui::PushStyleVar(ImGuiStyleVar_ItemSpacing, ImVec2{ 0, 0 });

	float lineHeight = GImGui->Font->FontSize + GImGui->Style.FramePadding.y * 2.0f;
	ImVec2 buttonSize = { lineHeight + 3.0f, lineHeight };

	ImGui::PushStyleColor(ImGuiCol_Button, ImVec4{ 0.8f, 0.1f, 0.15f, 1.0f });
	ImGui::PushStyleColor(ImGuiCol_ButtonHovered, ImVec4{ 0.9f, 0.2f, 0.2f, 1.0f });
	ImGui::PushStyleColor(ImGuiCol_ButtonActive, ImVec4{ 0.8f, 0.1f, 0.15f, 1.0f });
	if (ImGui::Button(x, buttonSize))
		values.x = resetValue;
	ImGui::PopStyleColor(3);

	ImGui::SameLine();
	ImGui::DragFloat("##X", &values.x, 0.1f, 0.0f, 0.0f, "%.2f");
	ImGui::PopItemWidth();
	ImGui::SameLine();

	ImGui::PushStyleColor(ImGuiCol_Button, ImVec4{ 0.2f, 0.7f, 0.2f, 1.0f });
	ImGui::PushStyleColor(ImGuiCol_ButtonHovered, ImVec4{ 0.3f, 0.8f, 0.3f, 1.0f });
	ImGui::PushStyleColor(ImGuiCol_ButtonActive, ImVec4{ 0.2f, 0.7f, 0.2f, 1.0f });
	if (ImGui::Button(y, buttonSize))
		values.y = resetValue;
	ImGui::PopStyleColor(3);

	ImGui::SameLine();
	ImGui::DragFloat("##Y", &values.y, 0.1f, 0.0f, 0.0f, "%.2f");
	ImGui::PopItemWidth();
	ImGui::SameLine();

	ImGui::PushStyleColor(ImGuiCol_Button, ImVec4{ 0.1f, 0.25f, 0.8f, 1.0f });
	ImGui::PushStyleColor(ImGuiCol_ButtonHovered, ImVec4{ 0.2f, 0.35f, 0.9f, 1.0f });
	ImGui::PushStyleColor(ImGuiCol_ButtonActive, ImVec4{ 0.1f, 0.25f, 0.8f, 1.0f });
	if (ImGui::Button(z, buttonSize))
		values.z = resetValue;
	ImGui::PopStyleColor(3);

	ImGui::SameLine();
	ImGui::DragFloat("##Z", &values.z, 0.1f, 0.0f, 0.0f, "%.2f");
	ImGui::PopItemWidth();

	ImGui::PopStyleVar();

	ImGui::Columns(1);

	ImGui::PopID();
}

void SceneHierarchyPannel::Context(const Ref<Scene>& context)
{
	m_Context = context;
	/*the m_scriptMap is a map that contains all the scripts object with the class hash_code as its key.
	* for now I have to mannually include all the scripts then manually bind them here (one by one)
	*/
	m_Context->m_scriptsMap[typeid(CustomScript).hash_code()] = new CustomScript();
}
void SceneHierarchyPannel::OnImGuiRender()
{
	bool isEntityDestroyed = false;
	Ref<Entity> m_Entity;
	ImGuiTreeNodeFlags flags = 0;
	ImGui::Begin("Scene Hierarchy Pannel");
	if (ImGui::Button("Save Scene", { 100,20 }))
	{
		SceneSerializer serialize(m_Context);
		serialize.Serialize("SceneSaved.hz");
	}
	if (ImGui::Button("Load Scene", { 100,20 }))
	{
		SceneSerializer serialize(m_Context);
		serialize.DeSerialize("SceneSaved.hz");
	}
		if (ImGui::BeginPopupContextWindow("Actions",1))
		{
			if (ImGui::Button("Create Entity", { 130,30 }))
			{
				m_Context->CreateEntity();
			}
			if (ImGui::Button("Add Point Light", { 130,30 }))
			{
				m_Context->AddPointLight(new PointLight({ 0,0,0 }, { 1,1,1 }));
			}
			ImGui::EndPopup();
		}
		m_Context->getRegistry().each([&](auto entity) {

			m_Entity = std::make_shared<Entity>(m_Context.get(), entity);

			std::string s = m_Entity->GetComponent<TagComponent>();

			if (m_selected_entity)
				flags = ImGuiTreeNodeFlags_SpanFullWidth | ImGuiTreeNodeFlags_OpenOnArrow | ((*m_selected_entity == *m_Entity) ? ImGuiTreeNodeFlags_Selected : 0);

			bool opened = ImGui::TreeNodeEx((void*)(uint32_t)*m_Entity, flags, s.c_str());

			if (ImGui::IsItemClicked())
				m_selected_entity = m_Entity;
			if (opened)
			{
				ImGui::TreePop();
			}
			});
		for (int i = 0; i < m_Context->m_PointLights.size(); i++)
		{
			std::string s = "Point Light_"+std::to_string(i);

			if (m_selected_Light) {
				flags = ImGuiTreeNodeFlags_SpanFullWidth | ImGuiTreeNodeFlags_OpenOnArrow;
			}
			bool opened = ImGui::TreeNodeEx(s.c_str(), flags);

			if (ImGui::IsItemClicked())
				m_selected_Light = m_Context->m_PointLights[i];
			if (opened)
			{
				ImGui::TreePop();
			}
		}
	if (ImGui::IsMouseClicked(0) && ImGui::IsWindowHovered())
		m_selected_entity = nullptr;

	if (m_selected_entity && ImGui::BeginPopupContextItem("Action"))
	{
		if (ImGui::Button("Delete Entity", { 100,30 })) {
			isEntityDestroyed = true;
			ImGui::CloseCurrentPopup();
		}
		ImGui::EndPopup();
	}

	ImGui::End();

	//properties pannel
	ImGui::Begin("Properties");

	if (m_selected_entity && ImGui::BeginPopupContextWindow("Actions",1))//click on any blank area to add component
	{
		if (ImGui::Button("Create Transform Component", { 220,30 }))
		{
			m_selected_entity->AddComponent<TransformComponent>();
		}
		
		if (ImGui::Button("Create Sprite Renderer Component", { 220,30 }))
		{
			m_selected_entity->AddComponent<SpriteRenderer>();
		}
		if (ImGui::Button("Create Camera Component", { 220,30 }))
		{
			m_selected_entity->AddComponent<CameraComponent>();
		}
		if (ImGui::Button("Create Physics Component", { 220,30 }))
		{
			m_selected_entity->AddComponent<PhysicsComponent>();
		}
		
		ImGui::EndPopup();
	}
	if (m_selected_entity.get() && m_selected_entity->HasComponent<TagComponent>())
	{
		DrawTagUI();
	}

	if (m_selected_entity.get() && m_selected_entity->HasComponent<TransformComponent>())
	{
		DrawTransformUI();
	}

	if (m_selected_entity.get() && m_selected_entity->HasComponent<StaticMeshComponent>())
	{
		DrawStaticMeshComponentUI();
	}

	if (m_selected_entity.get() && m_selected_entity->HasComponent<CameraComponent>())
	{
		DrawCameraUI();
	}
	
	if (m_selected_entity.get() && m_selected_entity->HasComponent<PhysicsComponent>())
	{
		DrawPhysicsComponentUI();
	}

	if (m_selected_entity.get())
		DrawScriptComponentUI();

	if (m_selected_entity.get() && m_selected_entity->HasComponent<SpriteRenderer>())
	{
		DrawSpriteRendererUI();
	
	}
	ImGui::End();

	ImGui::Begin("World Light Properties");
	if (m_selected_Light) 
	{
		glm::vec3 position = m_selected_Light->GetLightPosition();
		glm::vec3 color = m_selected_Light->GetLightColor();
		DrawVec3Control("Position", position);
		m_selected_Light->SetLightPosition(position);
		DrawVec3Control("Color", color,0,100,"R","G","B");
		m_selected_Light->SetLightColor(color);
	}
	ImGui::End();

	if (isEntityDestroyed)//delete entity
	{
		m_Context->DestroyEntity(*m_selected_entity);
		m_selected_entity = nullptr;
	}
}
void SceneHierarchyPannel::DrawHierarchyNode(const Entity* ent)
{
}
void SceneHierarchyPannel::DrawProperties()
{
}

void SceneHierarchyPannel::DrawTransformUI()
{
	if (!m_selected_entity)
		return;
	auto& transform = m_selected_entity->GetComponent<TransformComponent>();
	if (ImGui::TreeNodeEx((void*)typeid(TransformComponent).hash_code(), ImGuiTreeNodeFlags_OpenOnArrow | ImGuiTreeNodeFlags_SpanFullWidth | ImGuiTreeNodeFlags_DefaultOpen, "Transform Component")) //typeid() operator is a part of runtime type identification in cpp it determines the type of object at runtime
	{
		DrawVec3Control("Translation", transform.Translation);
		DrawVec3Control("Rotation", transform.Rotation);
		DrawVec3Control("Scale", transform.Scale, 1.0);

		ImGui::TreePop();
	}
}

void SceneHierarchyPannel::DrawCameraUI()
{
	if (!m_selected_entity)
		return;

	bool open = ImGui::TreeNodeEx(" Camera Component", ImGuiTreeNodeFlags_OpenOnArrow | ImGuiTreeNodeFlags_SpanFullWidth | ImGuiTreeNodeFlags_DefaultOpen);
	bool delete_component = false;
	ImGui::PushStyleVar(ImGuiStyleVar_WindowPadding, { 2,2 });
	ImGui::SameLine(ImGui::GetWindowWidth() - 40.f);
	if (ImGui::Button("+", { 20,20 }))
	{
		ImGui::OpenPopup("ComponentSettings1");
	}
	ImGui::PopStyleVar();
	if (ImGui::BeginPopup("ComponentSettings1"))
	{
		if (ImGui::MenuItem("Remove Component"))
			delete_component = true;
		ImGui::EndPopup();
	}
	auto& camera_comp = m_selected_entity->GetComponent<CameraComponent>();
	auto& camera = camera_comp.camera;
	const char* Items[] = { "Orthographic","Perspective" };
	const char* Selected_Item = Items[(int)camera.m_projection_type];
	if (open)
	{
		bool isPrimary = camera.bIsMainCamera;
		ImGui::Checkbox("Primary Camera", &isPrimary);
		camera.bIsMainCamera = isPrimary;

		if (isPrimary)//if the primary camera of one entity is true then set all entities primary camera to false(as you should have only one primary camera)
		{
			m_Context->getRegistry().view<CameraComponent>().each([&](entt::entity entity, CameraComponent& camerac)//get all entities that have camera component
				{
					Entity tmp_entity = Entity(m_Context.get(), entity);
					if (tmp_entity != *m_selected_entity)
					{
						camerac.camera.bIsMainCamera = false;
					}
				});
		}


		if (ImGui::BeginCombo("Projection Types", Selected_Item))
		{
			for (int i = 0; i < 2; i++)
			{
				bool bIsSelected = (Selected_Item == Items[i]);
				if (ImGui::Selectable(Items[i], bIsSelected))
				{
					Selected_Item = Items[i];
					camera.SetProjectionType((ProjectionTypes)i);
				}
				if (bIsSelected)
					ImGui::SetItemDefaultFocus();
			}
			ImGui::EndCombo();
		}

		if (camera.m_projection_type == ProjectionTypes::Orhtographic)
		{
			float OrthoSize = camera.GetOrthographicSize();
			if (ImGui::DragFloat("Orthographic size", &OrthoSize, 0.2, 0, 1000))
				camera.SetOrthographicSize(OrthoSize);

			float OrthoNear = camera.GetOrthographicNear();
			if (ImGui::DragFloat("Orthographic Near", &OrthoNear, 0.2, -100, 100))
				camera.SetOrthographicNear(OrthoNear);

			float OrthoFar = camera.GetOrthographicFar();
			if (ImGui::DragFloat("Orthographic Far", &OrthoFar, 0.2, 0, 1000))
				camera.SetOrthographicFar(OrthoFar);

		}
		else
		{
			float PersFOV = camera.GetVerticalFOV();
			if (ImGui::DragFloat("Perspective size", &PersFOV, 0.2))
				camera.SetVerticalFOV(PersFOV);

			float PersNear = camera.GetPerspectiveNear();
			if (ImGui::DragFloat("Perspective Near", &PersNear, 0.2))
				camera.SetPerspectiveNear(PersNear);

			float PersFar = camera.GetPerspectiveFar();
			if (ImGui::DragFloat("Perspective Far", &PersFar, 0.2))
				camera.SetPerspectiveFar(PersFar);
		}

		ImGui::Checkbox("Follow Player", &camera_comp.bFollowPlayer);
		DrawVec3Control("Camera Distance", camera_comp.camera_dist);
		ImGui::TreePop();
	}
	if (delete_component)
		m_selected_entity->RemoveComponent<CameraComponent>();
}
void SceneHierarchyPannel::DrawTagUI()
{
	if (!m_selected_entity)
		return;
	if (ImGui::TreeNodeEx("TAG Component", ImGuiTreeNodeFlags_OpenOnArrow | ImGuiTreeNodeFlags_SpanFullWidth | ImGuiTreeNodeFlags_DefaultOpen))
	{
		char buffer[200];
		TagComponent& tag = m_selected_entity->GetComponent<TagComponent>();
		std::string s = tag;
		jg_strcpy_s(buffer, sizeof(buffer), s.c_str());
		if (ImGui::InputText("TAG", buffer, sizeof(buffer)))
		{
			tag = std::string(buffer);
		}
		ImGui::TreePop();
	}
}
void SceneHierarchyPannel::DrawSpriteRendererUI()
{
	if (!m_selected_entity)
		return;
	ImGui::PushStyleVar(ImGuiStyleVar_WindowPadding, { 2,2 });
	bool open = ImGui::TreeNodeEx("Sprite Renderer", ImGuiTreeNodeFlags_SpanFullWidth | ImGuiTreeNodeFlags_DefaultOpen | ImGuiTreeNodeFlags_OpenOnArrow);
	bool delete_component = false;
	ImGui::SameLine(ImGui::GetWindowWidth()-40.f);
	if (ImGui::Button("+", {20,20}))
	{
		ImGui::OpenPopup("ComponentSettings");
	}
	ImGui::PopStyleVar();
	if (ImGui::BeginPopup("ComponentSettings"))
	{
		if (ImGui::MenuItem("Remove Component"))
		{
			delete_component = true;
		}
		ImGui::EndPopup();
	}
	if(open)
	{
		auto& Sprite_Renderer = m_selected_entity->GetComponent<SpriteRenderer>();
		static cBuffer buffer(texture_path);

		if ( ImGui::InputText("Texture Path", buffer.buff, static_cast<int>( sizeof(buffer.buff)/sizeof(char)) ) )
		{
			texture_path = std::string(buffer.buff);
			jg_strcpy_s(buffer.buff, sizeof(buffer.buff), texture_path.c_str());
		}
		if ( ImGui::Button("APPLY", {100,30}) )
		{
			Sprite_Renderer.texture = Texture2D::Create(texture_path);
		}

		ImGui::ColorEdit4("##Sprite", (float*)(&Sprite_Renderer.Color));
		ImGui::DragFloat("Emissive Strength", &Sprite_Renderer.Emission_Scale, 1);
		ImGui::DragFloat("Transperancy", &Sprite_Renderer.Transperancy, 0.01);
		ImGui::DragFloat("Roughness", &Sprite_Renderer.m_Roughness, 0.01, 0.0, 1.0);
		ImGui::DragFloat("Metallic", &Sprite_Renderer.m_Metallic, 0.01, 0.0, 1.0);
		ImGui::Checkbox("WireFrame", &Sprite_Renderer.m_WireFrame);

		ImGui::TreePop();
	}

	if (delete_component)
	{
		m_selected_entity->RemoveComponent<SpriteRenderer>();
	}
}
void SceneHierarchyPannel::DrawStaticMeshComponentUI()
{
	if (ImGui::TreeNodeEx("Static Mesh Component", ImGuiTreeNodeFlags_OpenOnArrow | ImGuiTreeNodeFlags_SpanFullWidth | ImGuiTreeNodeFlags_DefaultOpen))
	{
		if (ImGui::Button("Cube", { 100,30 }))
		{
			m_selected_entity->ReplaceComponent<StaticMeshComponent>(Scene::Cube);
		}
		if (ImGui::Button("Sphere", { 100,30 }))
		{
			m_selected_entity->ReplaceComponent<StaticMeshComponent>(Scene::Sphere);
		}
		if (ImGui::Button("Sphere_Simple", { 100,30 }))
		{
			m_selected_entity->ReplaceComponent<StaticMeshComponent>(Scene::Sphere_simple);
		}

		if (ImGui::Button("Freddy", { 100,30 }))
		{
			m_selected_entity->ReplaceComponent<StaticMeshComponent>(Scene::Freddy);
		}

		if (ImGui::Button("Plane", { 100,30 }))
		{
			m_selected_entity->ReplaceComponent<StaticMeshComponent>(Scene::Plane);
		}
		if (ImGui::Button("Plant", { 100,30 }))
		{
			m_selected_entity->ReplaceComponent<StaticMeshComponent>(Scene::plant);
		}
		if (ImGui::Button("House", { 100,30 }))
		{
			m_selected_entity->ReplaceComponent<StaticMeshComponent>(Scene::House);
		}
		if (ImGui::Button("Windmill", { 100,30 }))
		{
			m_selected_entity->ReplaceComponent<StaticMeshComponent>(Scene::Windmill);
		}
		if (ImGui::Button("Fern plant", { 100,30 }))
		{
			m_selected_entity->ReplaceComponent<StaticMeshComponent>(Scene::Grass);
			m_selected_entity->GetComponent<StaticMeshComponent>().isFoliage = true;
		}
		if (ImGui::Button("Sponza", { 100,30 }))
		{
			m_selected_entity->ReplaceComponent<StaticMeshComponent>(Scene::Sponza);
		}
		if (ImGui::Button("Flower", { 100,30 }))
		{
			m_selected_entity->ReplaceComponent<StaticMeshComponent>(Scene::Fern->GetLOD(1));
			m_selected_entity->GetComponent<StaticMeshComponent>().isFoliage = true;
		}
		if (ImGui::Checkbox("Is Foliage?", &m_selected_entity->GetComponent<StaticMeshComponent>().isFoliage))
		{
			m_selected_entity->GetComponent<StaticMeshComponent>().isFoliage = !m_selected_entity->GetComponent<StaticMeshComponent>().isFoliage;
		}
		LoadMesh* mesh = m_selected_entity->GetComponent<StaticMeshComponent>();
		for (const auto& sub_mesh : mesh->GetSubMeshes())
		{
			Ref<Material> mat = ResourceManager::allMaterials[sub_mesh.MaterialID];
			ImGui::Button(mat->m_MaterialName.c_str(), { 120,20 });
			if (ImGui::BeginDragDropTarget())//drag drop materials from content browser
			{
				if (const ImGuiPayload* val = ImGui::AcceptDragDropPayload("Material payload"))
				{
					ResourceManager::allMaterials[sub_mesh.MaterialID] = *(Ref<Material>*)val->Data;
				}
				ImGui::EndDragDropTarget();
			}
		}
		ImGui::TreePop();
	}
}
void SceneHierarchyPannel::DrawPhysicsComponentUI()
{
	ImGui::PushStyleVar(ImGuiStyleVar_WindowPadding, { 2,2 });
	bool open = ImGui::TreeNodeEx("Physics Component", ImGuiTreeNodeFlags_SpanFullWidth | ImGuiTreeNodeFlags_DefaultOpen | ImGuiTreeNodeFlags_OpenOnArrow);
	bool delete_component = false;
	ImGui::SameLine(ImGui::GetWindowWidth() - 40.f);
	if (ImGui::Button("+", { 20,20 }))
	{
		ImGui::OpenPopup("ComponentSettings");
	}
	ImGui::PopStyleVar();
	if (ImGui::BeginPopup("ComponentSettings"))
	{
		if (ImGui::MenuItem("Remove Component"))
			delete_component = true;
		ImGui::EndPopup();
	}
	if (open)
	{
		auto& physics_component = m_selected_entity->GetComponent<PhysicsComponent>();
		ImGui::DragFloat("Static Friction", &physics_component.m_StaticFriction, 0.1f);
		ImGui::DragFloat("Dynamic Friction", &physics_component.m_DynamicFriction, 0.1f);
		ImGui::DragFloat("Restitution", &physics_component.m_Restitution, 0.1f);
		ImGui::DragFloat("Mass", &physics_component.m_mass, 0.1f);
		ImGui::DragFloat("Sphere Radius", &physics_component.m_radius, 0.1f);
		ImGui::DragFloat("Angular Damping", &physics_component.m_AngularDamping, 0.1f);
		ImGui::DragFloat("Linear Damping", &physics_component.m_LinearDamping, 0.1f);
		DrawVec3Control("Box Collider Dimension", physics_component.m_halfextent);
		DrawVec3Control("Force Direction", physics_component.m_ForceDirection);
		ImGui::Checkbox("Is Actor Static", &physics_component.isStatic);
		ImGui::Checkbox("Is Kinematic", &physics_component.isKinematic);

		auto& transform = m_selected_entity->GetComponent<TransformComponent>();
		//if (ImGui::BeginPopupContextWindow("physics action", 1, false))
		//{

		if (ImGui::Button("Add Box collider", { 200.f,30.f }))
		{
			physics_component.m_transform = transform.GetTransform();
			Physics3D::AddBoxCollider(physics_component);
			physics_component.m_shapes = BOX_COLLIDER;
		}

		if (ImGui::Button("Add Sphere collider", { 200.f,30.f }))
		{
			physics_component.m_transform = transform.GetTransform();
			Physics3D::AddSphereCollider(physics_component);
			physics_component.m_shapes = SPHERE_COLLIDER;
		}

		// need to work on
		//if (ImGui::Button("Add Mesh collider", { 200.f,30.f }))

		if (ImGui::Button("Add Force"))
		{
			Physics3D::AddForce(physics_component);
		}

		if (ImGui::Button("Reset Simulation", { 100,20 }))
		{
			Physics3D::RemoveActor(physics_component);
			physics_component.ResetSimulation = true;
			m_selected_entity->GetComponent<TransformComponent>().m_transform = glm::mat4(1.0f);
		}

		ImGui::TreePop();
	}
}
void SceneHierarchyPannel::DrawScriptComponentUI()
{
	ImGui::PushStyleVar(ImGuiStyleVar_WindowPadding, { 2,2 });
	bool open = ImGui::TreeNodeEx("Script Component", ImGuiTreeNodeFlags_SpanFullWidth | ImGuiTreeNodeFlags_DefaultOpen | ImGuiTreeNodeFlags_OpenOnArrow);
	ImGui::PopStyleVar();

	if (open) {
		if (m_selected_entity->HasComponent<ScriptComponent>())
			ImGui::TextColored({ 0,1,0,1 }, "HAS A SELECTED SCRIPT");
		else
			ImGui::TextColored({ 1,0,0,1 }, "DOSENT HAVE A SELECTED SCRIPT");

		if (ImGui::Button("Add Custom Script", { 100,20 }))
			m_selected_entity->AddComponent<ScriptComponent>().Bind(*m_Context->m_scriptsMap[typeid(CustomScript).hash_code()]);

		ImGui::TreePop();
	}
}
