#pragma once

#include <string>

#include "Crimson/Core/Core.h"
#include "GPUHandle.h"

namespace Crimson {

    enum class ImageFormat
    {
        None = 0,
        
        // Color (Standard)
        R8,
        RGB8,
        RGBA8,
        
        // Color (HDR / Floating Point)
        R16F,
        RG16F,   
        RGB16F,
        RGBA16F,
        
        R32F,
        RG32F,
        RGB32F,
        RGBA32F,
        
        R32I,     
        
        // Depth / Stencil 
        DEPTH24STENCIL8, // Depth + Stencil
        DEPTH32F         // High Precision Depth 
    };

    class Texture
	{
	public:
		uint64_t uuid;
		Texture() = default;
		virtual ~Texture() = default;
		virtual uint32_t GetWidth() const = 0;
		virtual uint32_t GetHeight() const = 0;
		virtual GPUHandle GetHandle() const = 0;
		virtual void Bind(uint32_t slot) const = 0;
		virtual void UnBind() const = 0;
	};
	class Texture2D :public Texture {
	public:

		static bool ValidateTexture(const std::string& path);
		virtual unsigned short* GetTexture() = 0;
		virtual uint32_t GetChannels() const = 0;
		static Ref<Texture2D> Create(const std::string& path, bool bUse16BitTexture = false);
		static Ref<Texture2D> Create(const uint32_t Width, const uint32_t Height, const uint32_t data);
		static Ref<Texture2D> Create(const uint32_t Width, const uint32_t Height, ImageFormat format);

	};
	class Texture2DArray : public Texture {
	public:
		virtual void UnBind() const = 0;
		//default number of materials =1 , number of channels = 3
		static Ref<Texture2DArray> Create(const std::vector<std::string>& paths, int numMaterials = 1, int numChannels = 3, bool bUse16BitTexture = false);
	};

    class TextureCube : public Texture
    {
    public:
        static Ref<TextureCube> Create(uint32_t width, uint32_t height, ImageFormat format = ImageFormat::RGB16F);
        virtual void GenerateMips() = 0;
    };
}