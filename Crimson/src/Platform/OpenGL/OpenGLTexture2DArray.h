#pragma once
#include "Crimson/Core/Core.h"
#include "Crimson/Renderer/Texture.h"
namespace Crimson {
	class OpenGLTexture2DArray :public Texture2DArray
	{
	public:
		OpenGLTexture2DArray(const std::vector<std::string>& paths, int numMaterials, int numChannels, bool bUse16BitTexture );
		~OpenGLTexture2DArray();
		uint32_t GetWidth() const override { return m_Width; }
		uint32_t GetHeight() const override { return m_Height; }
		virtual void Bind(uint32_t slot) const override;
		virtual void UnBind() const override;
		virtual GPUHandle GetHandle() const override { return GPUHandle(m_RendererID); }
	
	private:
		int m_Width;
		int m_Height;
		int channels;
		uint32_t m_RendererID;
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
