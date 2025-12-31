#include "cnpch.h"
#include "ResourceManager.h"

namespace Crimson {
	std::unordered_map<uint64_t, Ref<Material>> ResourceManager::allMaterials;
	std::unordered_map<uint64_t, Ref<Texture>> ResourceManager::allTextures;
	std::unordered_map<uint64_t, Ref<LoadMesh>> ResourceManager::allMeshes;
}