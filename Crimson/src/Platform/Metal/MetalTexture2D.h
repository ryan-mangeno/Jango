#pragma once
#include "Crimson/Core/Core.h"
#include "Crimson/Renderer/Texture.h"

namespace Crimson {
    class MetalTexture2D : public Texture2D
    {
    public:
        MetalTexture2D(const std::string& path, bool bUse16BitTexture);
        MetalTexture2D(const uint32_t Width = 1, const uint32_t Height = 1, const uint32_t data = 0xffffffff);

        virtual ~MetalTexture2D();
        
        virtual uint32_t GetWidth() const override { return m_Width; }
        virtual uint32_t GetHeight() const override { return m_Height; }
        virtual uint32_t GetChannels() const override { return channels; }
        
        virtual void Bind(uint32_t slot) const override;
        virtual void UnBind() const override;
        
        // In Metal, we don't use int IDs, but we keep this for API compatibility
        // If you need the texture for ImGui, use GetTexturePointer() below
        virtual GPUHandle GetHandle() const override { return GPUHandle(m_Texture); }
        
        // Returns the raw Metal id<MTLTexture> cast to void*
        void* GetTexturePointer() const { return m_Texture; }

        unsigned short* GetTexture() override { return pixel_data_16; }

    private:
        int m_Width;
        int m_Height;
        int channels;
        
        // --- Metal Resource ---
        void* m_Texture = nullptr; // id<MTLTexture>

        // CPU Buffers
        unsigned short* resized_image_16 = nullptr;
        unsigned short* pixel_data_16 = nullptr;
        unsigned char* resized_image_8 = nullptr;
        unsigned char* pixel_data_8 = nullptr;

    private:
        void Resize_Image(const float& width, const float& height, bool bUse16BitTexture = false);
        void Create16BitTexture(const std::string& path);
        void Create8BitsTexture(const std::string& path);
        void CreateWhiteTexture();
        
        // Helper to generate mipmaps using a BlitEncoder
        void GenerateMipmaps();
    };

	class MetalTextureCube : public TextureCube
    {
    public:
        MetalTextureCube(uint32_t width, uint32_t height, ImageFormat format) {}
        virtual ~MetalTextureCube() { /* need to release texture maybe todo / to fix */ }

        virtual uint32_t GetWidth() const override { return m_Width; }
        virtual uint32_t GetHeight() const override { return m_Height; }
        virtual GPUHandle GetHandle() const override { return GPUHandle(m_Texture); } 

        void* GetMetalTexture() const { return m_Texture; }

        virtual void Bind(uint32_t slot) const override {}
        virtual void UnBind() const override {}

        virtual void GenerateMips() override {}

    private:
        uint32_t m_Width, m_Height;
        void* m_Texture; // id<MTLTexture>;
    
	};
}
