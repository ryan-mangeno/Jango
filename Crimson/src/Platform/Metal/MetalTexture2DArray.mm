#include "cnpch.h"
#include "MetalTexture2DArray.h"
#include "glad/glad.h"
#include "stb_image.h"
#include "Crimson/Core/Log.h"
#include "stb_image_resize.h"


namespace Crimson {

	MetalTexture2DArray::MetalTexture2DArray(const std::vector<std::string>& paths, int numMaterials, int channels, bool bUse16BitTexture)
		:m_Height(0), m_Width(0)
	{

		// If there are no texture paths, then a white texture is created along with a texture array
		if (paths.size() == 0)
		{
			CreateWhiteTextureArray(numMaterials);
		}
		else
		{
			if (bUse16BitTexture)
			{
				Create16BitTextures(paths, numMaterials);
			}
			else
			{
				Create8BitsTextures(paths, numMaterials);
			}
		}

	}

	MetalTexture2DArray::~MetalTexture2DArray()
	{
		glDeleteTextures(1, &m_RendererID);
	}

	void MetalTexture2DArray::Bind(int slot) const
	{
		// activates then binds tex and tex slot
		glBindTextureUnit(slot, m_RendererID);
	}

	void MetalTexture2DArray::UnBind() const
	{
		glBindTexture(GL_TEXTURE_2D_ARRAY, 0);
	}

	void MetalTexture2DArray::ResizeImage(const float width, const float height, bool bUse16BitTexture)
	{
		if (bUse16BitTexture)
		{
			if (m_Height > width && m_Width > height)
			{
				resized_image_16 = new unsigned short[width * height * channels];
				stbir_resize_uint16_generic(pixel_data_16, m_Width, m_Height, 0, resized_image_16, width, height, 0, channels, 0, 0, STBIR_EDGE_REFLECT, STBIR_FILTER_BOX, STBIR_COLORSPACE_LINEAR, 0);
				m_Height = height;
				m_Width = width;
				delete[] resized_image_16;
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
				delete[] resized_image_8;
			}

		}
	}

	void MetalTexture2DArray::Create16BitTextures(const std::vector<std::string>& paths, int numMaterials)
	{
		GLenum InternalFormat = 0, Format = 0;

		stbi_set_flip_vertically_on_load(1);
		pixel_data_16 = stbi_load_16(paths[0].c_str(), &m_Width, &m_Height, &channels, 0);

		if (pixel_data_16 == nullptr) {
			CN_CORE_ERROR("2D array Image not found!!");
			CreateWhiteTextureArray(numMaterials);
		}
		else 
		{
			//determine which format to use based on number of channels
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

			glCreateTextures(GL_TEXTURE_2D_ARRAY, 1, &m_RendererID);
			glTextureStorage3D(m_RendererID, 1, InternalFormat, m_Width, m_Height, paths.size());

			glGenerateTextureMipmap(m_RendererID);
			glTextureParameteri(m_RendererID, GL_TEXTURE_MIN_FILTER, GL_LINEAR_MIPMAP_LINEAR);
			glTextureParameteri(m_RendererID, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
			glTextureParameteri(m_RendererID, GL_TEXTURE_WRAP_S, GL_REPEAT);
			glTextureParameteri(m_RendererID, GL_TEXTURE_WRAP_R, GL_REPEAT);

			for (int i = 0; i < paths.size(); i++)
			{
				stbi_set_flip_vertically_on_load(1);
				pixel_data_16 = stbi_load_16(paths[i].c_str(), &m_Width, &m_Height, &channels, 0);

				if (pixel_data_16 == nullptr)
					CN_CORE_ERROR("Image not found");

				if (resized_image_16)
				{
					glTextureSubImage3D(m_RendererID, 0, 0, 0, i, m_Width, m_Height, 1, Format, GL_UNSIGNED_SHORT, resized_image_16);
					stbi_image_free(resized_image_16);
				}
				else if (pixel_data_16) 
				{
					glTextureSubImage3D(m_RendererID, 0, 0, 0, i, m_Width, m_Height, 1, Format, GL_UNSIGNED_SHORT, pixel_data_16);
					stbi_image_free(pixel_data_16);
				}
			}
		}

	}

	void MetalTexture2DArray::Create8BitsTextures(const std::vector<std::string>& paths, int numMaterials)
	{
		GLenum InternalFormat = 0;
		GLenum Format = 0;

		stbi_set_flip_vertically_on_load(1);
		pixel_data_8 = stbi_load(paths[0].c_str(), &m_Width, &m_Height, &channels, 0);

		if (pixel_data_8 == nullptr) {
			CN_CORE_ERROR("2D array Image not found, creating white texture array");
			CreateWhiteTextureArray(numMaterials);
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
			{
				CN_CORE_ERROR("Invalid Texture format");
			}

			glCreateTextures(GL_TEXTURE_2D_ARRAY, 1, &m_RendererID);
			glTextureStorage3D(m_RendererID, 1, InternalFormat, m_Width, m_Height, paths.size());

			glGenerateTextureMipmap(m_RendererID);
			glTextureParameteri(m_RendererID, GL_TEXTURE_MIN_FILTER, GL_LINEAR_MIPMAP_LINEAR);
			glTextureParameteri(m_RendererID, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
			glTextureParameteri(m_RendererID, GL_TEXTURE_WRAP_S, GL_REPEAT);
			glTextureParameteri(m_RendererID, GL_TEXTURE_WRAP_R, GL_REPEAT);

			for (int i = 0; i < paths.size(); i++)
			{
				stbi_set_flip_vertically_on_load(1);
				pixel_data_8 = stbi_load(paths[i].c_str(), &m_Width, &m_Height, &channels, 0);

				if (pixel_data_8 == nullptr)
					CN_CORE_ERROR("Image not found");


				if (resized_image_8)
				{
					glTextureSubImage3D(m_RendererID, 0, 0, 0, i, m_Width, m_Height, 1, Format, GL_UNSIGNED_BYTE, resized_image_8);
					stbi_image_free(resized_image_16);
				}
				else if (pixel_data_8) 
				{

					glTextureSubImage3D(m_RendererID, 0, 0, 0, i, m_Width, m_Height, 1, Format, GL_UNSIGNED_BYTE, pixel_data_8);
					stbi_image_free(pixel_data_8);
				}
			}
		}
	}

	void MetalTexture2DArray::CreateWhiteTextureArray(int numMaterials)
	{
		pixel_data_8 = stbi_load("Assets/Textures/White.jpg", &m_Width, &m_Height, &channels, 0);
		
		if (pixel_data_8 == nullptr)
			CN_CORE_ERROR("Image not found");

		ResizeImage(16, 16);

		glCreateTextures(GL_TEXTURE_2D_ARRAY, 1, &m_RendererID);
		glTextureStorage3D(m_RendererID, 1, GL_RGB8, 16, 16, numMaterials);

		glTextureParameteri(m_RendererID, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
		glTextureParameteri(m_RendererID, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
		glTextureParameteri(m_RendererID, GL_TEXTURE_WRAP_S, GL_REPEAT);
		glTextureParameteri(m_RendererID, GL_TEXTURE_WRAP_R, GL_REPEAT);

		for (int i = 0; i < numMaterials; i++) 
		{
			if (resized_image_8)
				glTextureSubImage3D(m_RendererID, 0, 0, 0, i, 16, 16, 1, GL_RGB, GL_UNSIGNED_BYTE, resized_image_8);
			else
				glTextureSubImage3D(m_RendererID, 0, 0, 0, i, m_Width, m_Height, 1, GL_RGB, GL_UNSIGNED_BYTE, pixel_data_8);
		}
	}

}