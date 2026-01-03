#pragma once
#include "Crimson/Core/Core.h"
#include "Crimson/Renderer/Texture.h"
namespace Crimson {
	class MetalTexture2DArray :public Texture2DArray
	{
	public:
		MetalTexture2DArray(const std::vector<std::string>& paths, int numMaterials, int numChannels, bool bUse16BitTexture );
		~MetalTexture2DArray();
		virtual uint32_t GetWidth() const override { return m_Width; }
		virtual uint32_t GetHeight() const override { return m_Height; }
		virtual void Bind(uint32_t slot) const override;
		virtual void UnBind() const override;
		virtual GPUHandle GetHandle() const override { return GPUHandle(m_Textures); }
		virtual void GenerateMipmaps();
	private:
		int m_Width;
		int m_Height;
		int channels;

		void* m_Textures; // id<MTLTexture>

		unsigned short* resized_image_16 = nullptr;
		unsigned short* pixel_data_16 = nullptr;
		unsigned char* resized_image_8 = nullptr;
		unsigned char* pixel_data_8 = nullptr;
	private:
		void ResizeImage(const float width, const float height, bool bUse16BitTexture = false);
		void Create16BitTextures(const std::vector<std::string>& paths, int numMaterials);
		void Create8BitsTextures(const std::vector<std::string>& paths, int numMaterials);
		void CreateWhiteTextureArray(int numMat);
	};
}
