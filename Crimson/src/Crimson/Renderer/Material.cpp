#include "cnpch.h"
#include "Material.h"
#include "Crimson/Scene/SceneSerializer.h"
#include "Crimson/Core/ResourceManager.h"

namespace Crimson
{
	Ref<Material> Material::m_material;
	uint32_t Material::materialNameOffset = 0;
	std::string Material::extension = ".mat";

	Ref<Material> Material::Create()
	{
		m_material = std::make_shared<Material>();
		return m_material;
	}
	Ref<Material> Material::Create(const std::string& material_name, const std::string& storage_path)
	{
		m_material = std::make_shared<Material>(material_name, storage_path);
		return m_material;
	}
	Material::Material()
	{
		materialNameOffset++; //increment when a material is created
		color = { 1,1,1,1 };
		roughness_multipler = 1;
		metallic_multipler = 0;
		normal_multipler = 1;
		emission = 0;

		UUID uuid;
		materialID = uuid;
	}
	Material::Material(const std::string& material_name, const std::string& storage_path)
	{

		CN_PROFILE_FUNCTION()

		m_MaterialName = material_name;
		materialNameOffset++; //increment when a material is created
		color = { 1,1,1,1 };
		roughness_multipler = 1;
		metallic_multipler = 0;
		normal_multipler = 1;
		emission = 0;

		if (storage_path == "")
		{
			std::filesystem::path materialpath("Assets/Materials");
			std::filesystem::create_directory(materialpath);
			std::string MatPath = (materialpath / std::filesystem::path(m_MaterialName + extension)).string();
			UUID uuid(MatPath); //create UUID based on material path
			materialID = uuid;
		}
		else
		{
			std::filesystem::path materialpath(storage_path);
			std::filesystem::create_directory(materialpath);
			std::string MatPath = (materialpath / std::filesystem::path(m_MaterialName + extension)).string();
			UUID uuid(MatPath); //create UUID based on material path
			materialID = uuid;
		}
	}
	void Material::SetTexturePaths(const std::string& albedo_path, const std::string& normal_path, const std::string& roughness_path)
	{
		albedoPath = albedo_path;
		normalPath = normal_path;
		roughnessPath = roughness_path;

		CreateTextures();
	}
	void Material::SetMaterialAttributes(const glm::vec4& color, float roughness, float metalness, float normal_strength)
	{
		this->color = color;
		roughness_multipler = roughness;
		metallic_multipler = metalness;
		normal_multipler = normal_strength;
	}
	void Material::SerializeMaterial(const std::string& path, const std::string& materialName)
	{
		if (path == "")
		{
			//if the material is not in resource manager then insert it
			if(ResourceManager::allMaterials.find(materialID) == ResourceManager::allMaterials.end())
				ResourceManager::allMaterials[materialID] = m_material; //can change but for now only enlist the material in resource manager in material serialization and deserialization
			
			std::filesystem::path materialpath("Assets/Materials");
			std::filesystem::create_directory(materialpath);
			m_MaterialName = materialName; //copy without extension
			std::string MatPath = (materialpath / std::filesystem::path(m_MaterialName + extension)).string();
			SceneSerializer serialize;
			serialize.SerializeMaterial(MatPath, *this);
		}
		else
		{
			//TODO custom path
		}
	}
	void Material::DeserializeMaterial()
	{
		//iterate through the directory and load the .mat files
		std::filesystem::path materialpath("Assets/Materials"); //needs to be changed as we should have the ability to iterate the entire solution
		for (auto& p : std::filesystem::directory_iterator(materialpath))
		{
			if (p.path().extension().string() == extension)
			{
				std::string file_name = (p.path().parent_path() / p.path().filename()).string();
				Ref<Material> mat = Create();
				SceneSerializer deserialize;
				deserialize.DeSerializeMaterial(file_name, *mat.get());
				mat->m_MaterialName = p.path().stem().string();
				ResourceManager::allMaterials[mat->materialID] = mat;
			}
		}
	}
	void Material::CreateTextures()
	{
		Diffuse_Texture = Texture2D::Create(albedoPath);
		Roughness_Texture = Texture2D::Create(roughnessPath);
		Normal_Texture = Texture2D::Create(normalPath,true);
	}
}