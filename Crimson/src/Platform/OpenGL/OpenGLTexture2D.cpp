#include "cnpch.h"
#include "OpenGLTexture2D.h"
#include "glad/glad.h"
#include "stb_image.h"
#include "Crimson/Core/Log.h"
#include "Crimson/Core/UUID.h"
#include "stb_image_resize.h"

namespace Crimson {

	OpenGLTexture2D::OpenGLTexture2D(const std::string& path, bool bUse16BitTexture)
		:m_Height(0), m_Width(0), channels(0)
	{
		uuid = UUID(path);
		if (bUse16BitTexture)
			Create16BitTexture(path);
		else
			Create8BitsTexture(path);
	}

	OpenGLTexture2D::OpenGLTexture2D(uint32_t width, uint32_t height, ImageFormat format)
        : m_Width(width), m_Height(height)
    {
        GLenum internalFormat = 0;
        GLenum dataFormat = 0;

        switch (format)
        {
            case ImageFormat::R8:
                internalFormat = GL_R8;
                dataFormat = GL_RED;
                break;
            case ImageFormat::RGB8:
                internalFormat = GL_RGB8;
                dataFormat = GL_RGB;
                break;
            case ImageFormat::RGBA8:
                internalFormat = GL_RGBA8;
                dataFormat = GL_RGBA;
                break;

            case ImageFormat::RG16F:
                internalFormat = GL_RG16F;
                dataFormat = GL_RG;
                break;
            case ImageFormat::RGB16F:
                internalFormat = GL_RGB16F;
                dataFormat = GL_RGB;
                break;
            case ImageFormat::RGBA16F:
                internalFormat = GL_RGBA16F;
                dataFormat = GL_RGBA;
                break;

            case ImageFormat::R32F:
                internalFormat = GL_R32F;
                dataFormat = GL_RED;
                break;
            case ImageFormat::RGB32F:
                internalFormat = GL_RGB32F;
                dataFormat = GL_RGB;
                break;
            case ImageFormat::RGBA32F:
                internalFormat = GL_RGBA32F;
                dataFormat = GL_RGBA;
                break;

            case ImageFormat::R32I:
                internalFormat = GL_R32I;
                dataFormat = GL_RED_INTEGER;
                break;
            
            case ImageFormat::DEPTH24STENCIL8:
                internalFormat = GL_DEPTH24_STENCIL8;
                dataFormat = GL_DEPTH_STENCIL;
                break;
            case ImageFormat::DEPTH32F:
                internalFormat = GL_DEPTH_COMPONENT32F;
                dataFormat = GL_DEPTH_COMPONENT;
                break;

            default:
                CN_CORE_ASSERT(false, "OpenGLTexture2D: Unknown ImageFormat!");
        }

        glCreateTextures(GL_TEXTURE_2D, 1, &m_Renderid);
        glTextureStorage2D(m_Renderid, 1, internalFormat, m_Width, m_Height);

        if (format == ImageFormat::R32I)
        {
            glTextureParameteri(m_Renderid, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
            glTextureParameteri(m_Renderid, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
        }
        else
        {
            glTextureParameteri(m_Renderid, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
            glTextureParameteri(m_Renderid, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
        }

        glTextureParameteri(m_Renderid, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
        glTextureParameteri(m_Renderid, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    }
	
	//data is defaulted to a color, can be used as a texture or base color also
	OpenGLTexture2D::OpenGLTexture2D(const uint32_t Width, const uint32_t Height, const uint32_t data)
		:m_Height(Height), m_Width(Width), channels(0)
	{

		GLenum InternalFormat = GL_RGBA8, Format = GL_RGBA;

		glCreateTextures(GL_TEXTURE_2D, 1, &m_Renderid);
		glTextureStorage2D(m_Renderid, 1, InternalFormat, m_Width, m_Height);

		glTextureParameteri(m_Renderid, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
		glTextureParameteri(m_Renderid, GL_TEXTURE_MAG_FILTER, GL_NEAREST);

		glTextureSubImage2D(m_Renderid, 0, 0, 0, m_Width, m_Height, Format, GL_UNSIGNED_BYTE, &data);

		glBindTexture(GL_TEXTURE_2D, 0);
	}

	void OpenGLTexture2D::Create16BitTexture(const std::string& path)
	{
		stbi_set_flip_vertically_on_load(1);
		pixel_data_16 = stbi_load_16(path.c_str(), &m_Width, &m_Height, &channels, 0);

		GLenum InternalFormat = 0, Format = 0;
		if (pixel_data_16 == nullptr) 
		{
			CN_CORE_ERROR("2D Image Not Found: {0}", path);
			CreateWhiteTexture();
		}
		else 
		{
			
			if (channels == 4)
			{
				InternalFormat = GL_RGBA16;
				Format = GL_RGBA;
			}
			else if (channels == 3)
			{
				InternalFormat = GL_RGB16;
				Format = GL_RGB;
			}
			else if (channels == 2)
			{
				InternalFormat = GL_RG16;
				Format = GL_RG;
			}
			else if (channels == 1)
			{
				InternalFormat = GL_R16;
				Format = GL_RED;
			}
			else
			{
				CN_CORE_ERROR("Invalid Texture format");
			}

			glCreateTextures(GL_TEXTURE_2D, 1, &m_Renderid);
			glTextureStorage2D(m_Renderid, 1, InternalFormat, m_Width, m_Height);

			glGenerateTextureMipmap(m_Renderid);
			glTextureParameteri(m_Renderid, GL_TEXTURE_MIN_FILTER, GL_LINEAR_MIPMAP_LINEAR);
			glTextureParameteri(m_Renderid, GL_TEXTURE_MAG_FILTER, GL_LINEAR_MIPMAP_NEAREST);
			glTextureParameteri(m_Renderid, GL_TEXTURE_WRAP_S, GL_REPEAT);
			glTextureParameteri(m_Renderid, GL_TEXTURE_WRAP_R, GL_REPEAT);

			if (resized_image_16)
			{
				glTextureSubImage2D(m_Renderid, 0, 0, 0, m_Width, m_Height, Format, GL_UNSIGNED_SHORT, resized_image_16);
				stbi_image_free(resized_image_16);
			}
			else if (pixel_data_16) 
			{
				glTextureSubImage2D(m_Renderid, 0, 0, 0, m_Width, m_Height, Format, GL_UNSIGNED_SHORT, pixel_data_16);
				stbi_image_free(pixel_data_16);
			}
			glBindTexture(GL_TEXTURE_2D, 0);
		}

	}

	void OpenGLTexture2D::Create8BitsTexture(const std::string& path)
	{
		GLenum InternalFormat = 0, Format = 0;

		stbi_set_flip_vertically_on_load(1);
		pixel_data_8 = stbi_load(path.c_str(), &m_Width, &m_Height, &channels, 0);

		if (pixel_data_8 == nullptr) 
		{
			CN_CORE_ERROR("2D Image not found: {0}", path);
			CreateWhiteTexture();
		}
		else 
		{
			if (channels == 4)
			{
				InternalFormat = GL_RGBA8;
				Format = GL_RGBA;
			}
			else if (channels == 3)
			{
				InternalFormat = GL_RGB8;
				Format = GL_RGB;
			}
			else if (channels == 2)
			{
				InternalFormat = GL_RG8;
				Format = GL_RG;
			}
			else if (channels == 1)
			{
				InternalFormat = GL_R8;
				Format = GL_RED;
			}
			else
				CN_CORE_ERROR("Invalid Texture format");

			glCreateTextures(GL_TEXTURE_2D, 1, &m_Renderid);
			glTextureStorage2D(m_Renderid, 1, InternalFormat, m_Width, m_Height);

			glGenerateTextureMipmap(m_Renderid);
			glTextureParameteri(m_Renderid, GL_TEXTURE_MIN_FILTER, GL_LINEAR_MIPMAP_LINEAR);
			glTextureParameteri(m_Renderid, GL_TEXTURE_MAG_FILTER, GL_LINEAR_MIPMAP_NEAREST);
			glTextureParameteri(m_Renderid, GL_TEXTURE_WRAP_S, GL_REPEAT);
			glTextureParameteri(m_Renderid, GL_TEXTURE_WRAP_R, GL_REPEAT);

			if (resized_image_8)
			{
				glTextureSubImage2D(m_Renderid, 0, 0, 0, m_Width, m_Height, Format, GL_UNSIGNED_BYTE, resized_image_8);
				stbi_image_free(resized_image_8);
			}
			else if (pixel_data_8)
			{
				glTextureSubImage2D(m_Renderid, 0, 0, 0, m_Width, m_Height, Format, GL_UNSIGNED_BYTE, pixel_data_8);
				stbi_image_free(pixel_data_8);
			}
			glBindTexture(GL_TEXTURE_2D, 0);
		}
	}

	OpenGLTexture2D::~OpenGLTexture2D()
	{
		glDeleteTextures(1, &m_Renderid);
	}
	void OpenGLTexture2D::Bind(uint32_t slot) const
	{
		glBindTextureUnit(slot, m_Renderid);
	}
	void OpenGLTexture2D::UnBind() const
	{
		glBindTexture(GL_TEXTURE_2D, 0);
	}
	void OpenGLTexture2D::CreateWhiteTexture()
	{
		pixel_data_8 = stbi_load("Assets/Textures/White.jpg", &m_Width, &m_Height, &channels, 0);
		
		if (pixel_data_8 == nullptr)
			CN_CORE_ERROR("Image not found");

		Resize_Image(16, 16);

		glCreateTextures(GL_TEXTURE_2D, 1, &m_Renderid);
		glTextureStorage2D(m_Renderid, 1, GL_RGB8, 16, 16);

		glGenerateTextureMipmap(m_Renderid);
		glTextureParameteri(m_Renderid, GL_TEXTURE_MIN_FILTER, GL_LINEAR_MIPMAP_LINEAR);
		glTextureParameteri(m_Renderid, GL_TEXTURE_MAG_FILTER, GL_LINEAR_MIPMAP_NEAREST);
		glTextureParameteri(m_Renderid, GL_TEXTURE_WRAP_S, GL_REPEAT);
		glTextureParameteri(m_Renderid, GL_TEXTURE_WRAP_R, GL_REPEAT);

		if (resized_image_8)
		{
			glTextureSubImage2D(m_Renderid, 0, 0, 0, 16, 16, GL_RGB, GL_UNSIGNED_BYTE, resized_image_8);
			stbi_image_free(resized_image_8);
		}
		else if (pixel_data_8) 
		{
			glTextureSubImage2D(m_Renderid, 0, 0, 0, m_Width, m_Height, GL_RGB, GL_UNSIGNED_BYTE, pixel_data_8);
			stbi_image_free(pixel_data_8);
		}
		glBindTexture(GL_TEXTURE_2D, 0);
	}

	void OpenGLTexture2D::Resize_Image(const float& width, const float& height, bool bUse16BitTexture)
	{
		if (bUse16BitTexture)
		{
			if (m_Height > width && m_Width > height)
			{
				resized_image_16 = new unsigned short[width * height * channels];
				stbir_resize_uint16_generic(pixel_data_16, m_Width, m_Height, 0, resized_image_16, width, height, 0, channels, 0, 0, STBIR_EDGE_REFLECT, STBIR_FILTER_BOX, STBIR_COLORSPACE_LINEAR, 0);
				m_Height = height;
				m_Width = width;
			}
		}
		else
		{
			if (m_Height > width && m_Width > height)
			{
				resized_image_8 = new unsigned char[width * height * channels];
				stbir_resize_uint8(pixel_data_8, m_Width, m_Height, 0, resized_image_8, width, height, 0, channels);
				m_Height = height;
				m_Width = width;
			}
		}
	}


	OpenGLTextureCube::OpenGLTextureCube(uint32_t width, uint32_t height, ImageFormat format)
        : m_Width(width), m_Height(height)
    {
        glGenTextures(1, &m_RendererID);
        glBindTexture(GL_TEXTURE_CUBE_MAP, m_RendererID);

        m_InternalFormat = GL_RGB16F; // Default to HDR
        m_DataFormat = GL_RGB;
        
        if (format == ImageFormat::RGB8)
        {
            m_InternalFormat = GL_RGB8;
            m_DataFormat = GL_RGB;
        }

        for (uint32_t i = 0; i < 6; ++i)
        {
            glTexImage2D(GL_TEXTURE_CUBE_MAP_POSITIVE_X + i, 0, m_InternalFormat, width, height, 0, m_DataFormat, GL_FLOAT, nullptr);
        }

        glTexParameteri(GL_TEXTURE_CUBE_MAP, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
        glTexParameteri(GL_TEXTURE_CUBE_MAP, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
        glTexParameteri(GL_TEXTURE_CUBE_MAP, GL_TEXTURE_WRAP_R, GL_CLAMP_TO_EDGE);
        glTexParameteri(GL_TEXTURE_CUBE_MAP, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_CUBE_MAP, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    }

    OpenGLTextureCube::~OpenGLTextureCube()
    {
        glDeleteTextures(1, &m_RendererID);
    }

    void OpenGLTextureCube::Bind(uint32_t slot) const
    {
        glBindTextureUnit(slot, m_RendererID);
    }

    void OpenGLTextureCube::GenerateMips()
    {
        glBindTexture(GL_TEXTURE_CUBE_MAP, m_RendererID);
        glGenerateMipmap(GL_TEXTURE_CUBE_MAP);
        // Update filter for mipmaps
        glTexParameteri(GL_TEXTURE_CUBE_MAP, GL_TEXTURE_MIN_FILTER, GL_LINEAR_MIPMAP_LINEAR);
    }
}