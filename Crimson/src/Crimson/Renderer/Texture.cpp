#include "cnpch.h"
#include "Texture.h"
#include "stb_image.h"
#include "RendererAPI.h"
#include "Crimson/Core/ResourceManager.h"
#include "Platform/Opengl/OpenGlTexture2D.h"
#include "Platform/Opengl/OpenGlTexture2DArray.h"

namespace Crimson {
	bool Texture2D::ValidateTexture(const std::string& path)
	{
		int channels = 0;
		int height = 0, width = 0;
		stbi_uc* pixel_data = stbi_load(path.c_str(), &width, &height, &channels, 0);
		if (pixel_data == nullptr)
		{
			return false;
		}
		else
		{
			stbi_image_free(pixel_data);
			return true;
		}
	}
	Ref<Texture2D> Texture2D::Create(const std::string& path, bool bUse16BitTexture)
	{
		Ref<Texture2D> instance;
		uint64_t ID = 0;
		switch (RendererAPI::GetAPI()) 
		{
			case GraphicsAPI::None:
				return nullptr;
			case GraphicsAPI::OpenGL:
				ID = UUID(path);
				if (ResourceManager::allTextures.find(ID) == ResourceManager::allTextures.end())// load a texture only once
				{
					CN_CORE_INFO("Making Instance ...");
					instance = MakeRef<OpenGLTexture2D>(path, bUse16BitTexture);
					CN_CORE_INFO("Made Instance ...");
					ResourceManager::allTextures[instance->uuid] = instance;
				}
				else
					instance = std::dynamic_pointer_cast<Texture2D>(ResourceManager::allTextures[ID]); //dynamic_pointer_cast helps to give a shared ptr of derived type casting from base
				return instance;
			default:
				return nullptr;
		}
	}
	Ref<Texture2D> Texture2D::Create(const unsigned int Width, const unsigned int Height, const unsigned int data)
	{
		switch (RendererAPI::GetAPI()) 
		{
			case GraphicsAPI::None:
				return nullptr;
			case GraphicsAPI::OpenGL:
				return MakeRef<OpenGLTexture2D>(Width, Height, data);
			default:
				return nullptr;
		}
	}
	Ref<Texture2DArray> Texture2DArray::Create(const std::vector<std::string>& paths, int numMaterials, int numChannels, bool bUse16BitTexture)
	{
		switch (RendererAPI::GetAPI()) 
		{
			case GraphicsAPI::None:
				return nullptr;
			case GraphicsAPI::OpenGL:
				return std::make_shared<OpenGLTexture2DArray>(paths, numMaterials, numChannels, bUse16BitTexture);
			default:
				return nullptr;
		}
	}
}
