#include "cnpch.h"
#include "Texture.h"
#include "stb_image.h"
#include "RendererAPI.h"
#include "Crimson/Core/ResourceManager.h"

#include "Platform/OpenGL/OpenGLTexture2D.h"
#include "Platform/OpenGL/OpenGLTexture2DArray.h"

#include "Platform/Metal/MetalTexture2D.h"
#include "Platform/Metal/MetalTexture2DArray.h"

namespace Crimson {
	bool Texture2D::ValidateTexture(const std::string& path)
	{
		int channels = 0;
		int height = 0, width = 0;

		stbi_uc* pixel_data = stbi_load(path.c_str(), &width, &height, &channels, 0);
		if (pixel_data == nullptr) {
			return false;
		} else {
			stbi_image_free(pixel_data);
			return true;
		}
	}
	Ref<Texture2D> Texture2D::Create(const std::string& path, bool bUse16BitTexture)
	{
		Ref<Texture2D> instance;
		uint64_t ID = 0;

		CN_CORE_TRACE("Creating texture: {0}", path.c_str());
		
		switch (RendererAPI::GetAPI()) 
		{
			case GraphicsAPI::None:
				return nullptr;
			case GraphicsAPI::OpenGL:
				ID = UUID(path);
				if (ResourceManager::allTextures.find(ID) == ResourceManager::allTextures.end()) {
					instance = MakeRef<OpenGLTexture2D>(path, bUse16BitTexture);
					ResourceManager::allTextures[instance->uuid] = instance;
				} else {
					instance = std::dynamic_pointer_cast<OpenGLTexture2D>(ResourceManager::allTextures[ID]); //dynamic_pointer_cast helps to give a shared ptr of derived type casting from base
				}
				return instance;
			case GraphicsAPI::Metal:
				ID = UUID(path);
				if (ResourceManager::allTextures.find(ID) == ResourceManager::allTextures.end()) /* load a texture only once */ {
					instance = MakeRef<MetalTexture2D>(path, bUse16BitTexture);
					ResourceManager::allTextures[instance->uuid] = instance;
				} else {
					instance = std::dynamic_pointer_cast<MetalTexture2D>(ResourceManager::allTextures[ID]); //dynamic_pointer_cast helps to give a shared ptr of derived type casting from base
				}
				return instance;
			default:
				return nullptr;
		}
	}

	Ref<Texture2D> Texture2D::Create(const uint32_t Width, const uint32_t Height, const uint32_t data)
	{
		switch (RendererAPI::GetAPI()) 
		{
			case GraphicsAPI::None:
				return nullptr;
			case GraphicsAPI::OpenGL:
				return MakeRef<OpenGLTexture2D>(Width, Height, data);
			case GraphicsAPI::Metal:
				return MakeRef<MetalTexture2D>(Width, Height, data);;
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
				return MakeRef<OpenGLTexture2DArray>(paths, numMaterials, numChannels, bUse16BitTexture);
			case GraphicsAPI::Metal:
				return MakeRef<MetalTexture2DArray>(paths, numMaterials, numChannels, bUse16BitTexture);
			default:
				return nullptr;
		}
	}

	Ref<TextureCube> TextureCube::Create(uint32_t width, uint32_t height, ImageFormat format)
    {
        switch (RendererAPI::GetAPI())
        {
            case GraphicsAPI::None:    CN_CORE_ASSERT(false, "RendererAPI::None is currently not supported"); return nullptr;
            case GraphicsAPI::OpenGL:  return MakeRef<OpenGLTextureCube>(width, height, format);
            case GraphicsAPI::Metal:   return MakeRef<MetalTextureCube>(width, height, format);
        }
        CN_CORE_ASSERT(false, "Unknown RendererAPI");
        return nullptr;
    }

	Ref<Texture2D> Texture2D::Create(uint32_t width, uint32_t height, ImageFormat format)
    {
        switch (RendererAPI::GetAPI())
        {
            case GraphicsAPI::None:    CN_CORE_ASSERT(false, "RendererAPI::None is currently not supported"); return nullptr;
            case GraphicsAPI::OpenGL:  return MakeRef<OpenGLTexture2D>(width, height, format);
            case GraphicsAPI::Metal:   return MakeRef<MetalTexture2D>(width, height, format);
        }
        CN_CORE_ASSERT(false, "Unknown RendererAPI");
        return nullptr;
    }
}
