#pragma once

#define GLM_ENABLE_EXPERIMENTAL

#include "Crimson/Core/Core.h"
#include "Crimson/Renderer/Material.h"
#include "Crimson/Renderer/Texture.h"
#include "Crimson/Mesh/LoadMesh.h"

namespace Crimson {
	class ResourceManager {
	public:
		ResourceManager() = default;
	public:
		static std::unordered_map<uint64_t, Ref<Material>> allMaterials;
		static std::unordered_map<uint64_t, Ref<Texture>> allTextures;
		static std::unordered_map<uint64_t, Ref<LoadMesh>> allMeshes;
	};
}