#include "cnpch.h"
#include "MetalTexture2DArray.h"
#include "MetalRendererAPI.h"

#include "stb_image.h"
#include "stb_image_resize.h"

#import <Metal/Metal.h>

namespace Crimson {

    MetalTexture2DArray::MetalTexture2DArray(const std::vector<std::string>& paths, int numMaterials, int channels, bool bUse16BitTexture)
        : m_Height(0), m_Width(0)
    {
        if (paths.empty())
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
        if (m_Textures)
        {
            CFRelease(m_Textures);
            m_Textures = nullptr;
        }
    }

    void MetalTexture2DArray::Bind(uint32_t slot) const
    {
        id<MTLRenderCommandEncoder> encoder = (__bridge id<MTLRenderCommandEncoder>)MetalRendererAPI::GetCurrentEncoder();
        if (encoder && m_Textures)
        {
            // bind to fragment shader at the requested slot
            [encoder setFragmentTexture:(__bridge id<MTLTexture>)m_Textures atIndex:slot];
        }
    }

    void MetalTexture2DArray::UnBind() const
    {
        // Metal doesn't require explicit unbinds, but you could bind nil if needed
    }

    void MetalTexture2DArray::GenerateMipmaps()
    {
        if (!m_Textures) return;
        
        id<MTLCommandQueue> queue = (__bridge id<MTLCommandQueue>)MetalRendererAPI::GetCommandQueue();
        id<MTLCommandBuffer> cmdBuffer = [queue commandBuffer];
        id<MTLBlitCommandEncoder> blit = [cmdBuffer blitCommandEncoder];
        
        [blit generateMipmapsForTexture:(__bridge id<MTLTexture>)m_Textures];
        
        [blit endEncoding];
        [cmdBuffer commit];
        [cmdBuffer waitUntilCompleted];
    }

    void MetalTexture2DArray::Create16BitTextures(const std::vector<std::string>& paths, int numMaterials)
    {
        stbi_set_flip_vertically_on_load(1);
        
        // Load First Image to determine dimensions
        int desired_channels = 4; // Metal requires RGBA
        int w, h, c;
        unsigned short* data = stbi_load_16(paths[0].c_str(), &w, &h, &c, desired_channels);

        if (!data) {
            CN_CORE_ERROR("2D array Image not found {0}", paths[0]);
            CreateWhiteTextureArray(numMaterials);
            return;
        }

        m_Width = w;
        m_Height = h;
        
        // Texture Descriptor
        MTLTextureDescriptor* desc = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA16Unorm // or RGBA16Float
                                                                                        width:m_Width 
                                                                                       height:m_Height 
                                                                                    mipmapped:YES];
        desc.textureType = MTLTextureType2DArray;
        desc.arrayLength = paths.size(); // Set Depth/Layers
        desc.usage = MTLTextureUsageShaderRead | MTLTextureUsageRenderTarget; // RenderTarget needed for GenerateMips
        
        id<MTLDevice> device = (__bridge id<MTLDevice>)MetalRendererAPI::GetDevice();
        m_Textures = (__bridge_retained void*)[device newTextureWithDescriptor:desc];
        
        // Upload First Image
        MTLRegion region = MTLRegionMake2D(0, 0, m_Width, m_Height);
        id<MTLTexture> texture = (__bridge id<MTLTexture>)m_Textures;
        
        [texture replaceRegion:region 
                   mipmapLevel:0 
                         slice:0 
                     withBytes:data 
                   bytesPerRow:m_Width * 4 * sizeof(unsigned short) 
                 bytesPerImage:0];

        stbi_image_free(data);

        // Load & Upload Remaining Images
        for (size_t i = 1; i < paths.size(); i++)
        {
            data = stbi_load_16(paths[i].c_str(), &w, &h, &c, desired_channels);
            if (data)
            {
                [texture replaceRegion:region 
                           mipmapLevel:0 
                           slice:i 
                           withBytes:data 
                           bytesPerRow:m_Width * 4 * sizeof(unsigned short) 
                           bytesPerImage:0];
                stbi_image_free(data);
            }
            else
            {
                CN_CORE_ERROR("Failed to load texture layer: {0}", paths[i]);
            }
        }
        
        GenerateMipmaps();
    }

    void MetalTexture2DArray::Create8BitsTextures(const std::vector<std::string>& paths, int numMaterials)
    {
        stbi_set_flip_vertically_on_load(1);
        
        int desired_channels = 4; 
        int w, h, c;
        unsigned char* data = stbi_load(paths[0].c_str(), &w, &h, &c, desired_channels);

        if (!data) {
            CN_CORE_ERROR("2D array Image not found {0}, Creating White Texture Array", paths[0]);
            CreateWhiteTextureArray(numMaterials);
            return;
        }

        m_Width = w;
        m_Height = h;

        MTLTextureDescriptor* desc = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA8Unorm 
                                                                                        width:m_Width 
                                                                                       height:m_Height 
                                                                                    mipmapped:YES];
        desc.textureType = MTLTextureType2DArray;
        desc.arrayLength = paths.size();
        desc.usage = MTLTextureUsageShaderRead | MTLTextureUsageRenderTarget; // Required for mipmap generation

        id<MTLDevice> device = (__bridge id<MTLDevice>)MetalRendererAPI::GetDevice();
        m_Textures = (__bridge_retained void*)[device newTextureWithDescriptor:desc];
        id<MTLTexture> texture = (__bridge id<MTLTexture>)m_Textures;

        MTLRegion region = MTLRegionMake2D(0, 0, m_Width, m_Height);
        
        [texture replaceRegion:region 
                   mipmapLevel:0 
                         slice:0 
                     withBytes:data 
                   bytesPerRow:m_Width * 4 // 4 bytes per pixel (RGBA)
                 bytesPerImage:0];
                 
        stbi_image_free(data);

        for (size_t i = 1; i < paths.size(); i++)
        {
            data = stbi_load(paths[i].c_str(), &w, &h, &c, desired_channels);
            if (data)
            {
                // Resize logic if need 
                // GPU upload expects same size as created texture
                if (w != m_Width || h != m_Height) {
                    // resize here if needed using stbir
                }

                [texture replaceRegion:region 
                           mipmapLevel:0 
                           slice:i 
                           withBytes:data 
                           bytesPerRow:m_Width * 4 
                           bytesPerImage:0];
                         
                stbi_image_free(data);
            }
            else
            {
                CN_CORE_ERROR("Failed to load texture layer {0}", paths[i]);
            }
        }

        GenerateMipmaps();
    }

    void MetalTexture2DArray::CreateWhiteTextureArray(int numMaterials)
    {
        m_Width = 16;
        m_Height = 16;
        
        // buffer of solid white pixels (RGBA)
        uint32_t whiteData = 0xffffffff; // R=255, G=255, B=255, A=255
        std::vector<uint32_t> pixels(m_Width * m_Height, whiteData);

        MTLTextureDescriptor* desc = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA8Unorm 
                                                                                        width:m_Width 
                                                                                       height:m_Height 
                                                                                    mipmapped:YES];
        desc.textureType = MTLTextureType2DArray;
        desc.arrayLength = numMaterials;
        desc.usage = MTLTextureUsageShaderRead | MTLTextureUsageRenderTarget;

        id<MTLDevice> device = (__bridge id<MTLDevice>)MetalRendererAPI::GetDevice();
        m_Textures = (__bridge_retained void*)[device newTextureWithDescriptor:desc];
        id<MTLTexture> texture = (__bridge id<MTLTexture>)m_Textures;

        // fill every slice with white
        MTLRegion region = MTLRegionMake2D(0, 0, m_Width, m_Height);
        
        for (int i = 0; i < numMaterials; i++)
        {
            [texture replaceRegion:region 
                       mipmapLevel:0 
                       slice:i 
                       withBytes:pixels.data() 
                       bytesPerRow:m_Width * 4 
                       bytesPerImage:0];
        }
        
        GenerateMipmaps();
    }
}