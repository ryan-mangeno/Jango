#pragma once

#include "Crimson/Renderer/Shader.h"
#include "Crimson/Renderer/Texture.h"
#include "Crimson/Core/UUID.h"

namespace Crimson
{
	class Material
	{
	public:
		Material();
		Material(const std::string& material_name, const std::string& storage_path = "");

		static Ref<Material> Create();
		//if storage path is blank then use the default storage path
		static Ref<Material> Create(const std::string& material_name, const std::string& storage_path = "");
		void SetTexturePaths(const std::string& albedo_path , const std::string& normal_path , const std::string& roughness_path);
		void SetMaterialAttributes(const glm::vec4& color, float roughness, float metalness, float normal_strength);
		void SerializeMaterial(const std::string& path, const std::string& materialName);
		void SetEmission(float emission) { this->emission = emission; }
		void SetShader(Ref<Shader> shader) { RenderShader = shader; }
		inline Ref<Shader> GetShader() { return RenderShader; }
		inline glm::vec4 GetColor() { return color; }
		inline float GetRoughness() { return roughness_multipler; }
		inline float GetMetalness() { return metallic_multipler; }
		inline float GetNormalStrength() { return normal_multipler; }
		inline float GetEmission() { return emission; }
		inline std::string GetAlbedoPath() { return albedoPath; }
		inline std::string GetNormalPath() { return normalPath; }
		inline std::string GetRoughnessPath() { return roughnessPath; }

		static void DeserializeMaterial(); //iterate through the solution directory and load the ".mat" files
	private:
		void CreateTextures();
	public:
		uint64_t materialID;
		std::string m_MaterialName;
		Ref<Texture2D> Diffuse_Texture;
		Ref<Texture2D> Roughness_Texture ;
		Ref<Texture2D> Normal_Texture;
	private:
		static Ref<Material> m_material;
		static uint32_t materialNameOffset;
		static std::string extension;
		glm::vec4 color;
		float metallic_multipler;
		float roughness_multipler;
		float normal_multipler;
		float emission;
		std::string albedoPath = "";
		std::string normalPath = "";
		std::string roughnessPath = "";
		Ref<Shader> RenderShader;
	};
}