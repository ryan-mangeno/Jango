#pragma once
#include "Crimson/Core/Core.h"
#include "Crimson/Renderer/Texture.h"
namespace Crimson {
	class MetalTexture2D :public Texture2D
	{
	public:
		MetalTexture2D(const std::string& path, bool bUse16BitTexture);
		MetalTexture2D(const unsigned int Width = 1, const unsigned int Height = 1, unsigned int data = 0xffffffff);
		virtual ~MetalTexture2D();
		unsigned int GetWidth() const override { return m_Width; }
		unsigned int GetHeight() const override { return m_Height; }
		unsigned int GetChannels() override { return channels; }
		virtual void Bind(int slot)const override;
		virtual void UnBind()const override;
		unsigned int GetID() const override { return m_Renderid; }
		unsigned short* GetTexture() override { return pixel_data_16; }//will not work as pixel_data is deleted
	private:
		 int m_Width;
		 int m_Height;
		 int channels;
		unsigned int m_Renderid;
		unsigned short* resized_image_16 = nullptr;
		unsigned short* pixel_data_16 = nullptr;
		unsigned char* resized_image_8 = nullptr;
		unsigned char* pixel_data_8 = nullptr;
	private:
		void Resize_Image(const float& width, const float& height, bool bUse16BitTexture = false);
		void Create16BitTexture(const std::string& path);
		void Create8BitsTexture(const std::string& path);
		void CreateWhiteTexture();


	};
}
