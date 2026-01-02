#pragma once
#include "Crimson/Core/Core.h"
#include "Crimson/Renderer/Texture.h"
namespace Crimson {
	class OpenGLTexture2D :public Texture2D
	{
	public:
		OpenGLTexture2D(const std::string& path, bool bUse16BitTexture);
		OpenGLTexture2D(const uint32_t Width = 1, const uint32_t Height = 1, const uint32_t data = 0xffffffff);
		virtual ~OpenGLTexture2D();
		virtual uint32_t GetWidth() const override { return m_Width; }
		virtual uint32_t GetHeight() const override { return m_Height; }
		virtual uint32_t GetChannels() const override { return channels; }
		virtual void Bind(uint32_t slot) const override;
		virtual void UnBind() const override;
		virtual GPUHandle GetHandle() const override { return GPUHandle(m_Renderid); }
		unsigned short* GetTexture() override { return pixel_data_16; }//will not work as pixel_data is deleted
	private:
		 int m_Width;
		 int m_Height;
		 int channels;
		uint32_t m_Renderid;
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

	class OpenGLTextureCube : public TextureCube
    {
    public:
        OpenGLTextureCube(uint32_t width, uint32_t height, ImageFormat format);
        virtual ~OpenGLTextureCube();

        virtual uint32_t GetWidth() const override { return m_Width; }
        virtual uint32_t GetHeight() const override { return m_Height; }
        virtual GPUHandle GetHandle() const override { return GPUHandle(m_RendererID); }
        
        inline virtual void Bind(uint32_t slot) const override {}; // todo
        inline virtual void UnBind() const override {}; // todo

        virtual void GenerateMips() override;
        inline bool operator==(const Texture& other) const
        {
            return m_RendererID == ((OpenGLTextureCube&)other).m_RendererID;
        }
    private:
        uint32_t m_Width, m_Height;
        uint32_t m_RendererID;
        uint32_t m_InternalFormat, m_DataFormat;
    };
}
