#include "cnpch.h"
#include "MetalTexture2D.h"
#include "MetalRendererAPI.h" 
#include "Crimson/Core/UUID.h"

#import <Metal/Metal.h>
#include "stb_image.h"
#include "stb_image_resize.h"

namespace Crimson {



    static MTLPixelFormat ImgFmtToMtlFmt(ImageFormat format) {
        switch (format)
        {
            case ImageFormat::R8:
                return MTLPixelFormatR8Unorm;
            case ImageFormat::RG16F: // BRDF LUT
                return MTLPixelFormatRG16Float;

            // 3 & 4 Channels (Must use RGBA on Metal)
            case ImageFormat::RGB8:
            case ImageFormat::RGBA8:
                return MTLPixelFormatRGBA8Unorm; 
            
            case ImageFormat::RGB16F:
            case ImageFormat::RGBA16F:
                return MTLPixelFormatRGBA16Float; // HDR

            case ImageFormat::RGB32F:
            case ImageFormat::RGBA32F:
                return MTLPixelFormatRGBA32Float;

            case ImageFormat::R32I:
                return MTLPixelFormatR32Sint; 

            // Depth Formats
            case ImageFormat::DEPTH32F:
                return MTLPixelFormatDepth32Float;
            case ImageFormat::DEPTH24STENCIL8:
                return MTLPixelFormatDepth24Unorm_Stencil8;

            default:
                CN_CORE_WARN("MetalTexture: Unknown format, defaulting to RGBA8");
                return MTLPixelFormatRGBA8Unorm;
        }
    }

    MetalTexture2D::MetalTexture2D(const std::string& path, bool bUse16BitTexture)
        : m_Height(0), m_Width(0), channels(0)
    {
        uuid = UUID(path); 
        if (bUse16BitTexture) Create16BitTexture(path);
        else                  Create8BitsTexture(path);
    }
    
    // Single color texture (usually white/solid)
    MetalTexture2D::MetalTexture2D(const uint32_t Width, const uint32_t Height, const uint32_t data)
        : m_Height(Height), m_Width(Width), channels(4)
    {
        id<MTLDevice> device = (__bridge id<MTLDevice>)MetalRendererAPI::GetDevice();

        MTLTextureDescriptor* textureDesc = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA8Unorm 
                                                                                            width:m_Width 
                                                                                            height:m_Height 
                                                                                         	mipmapped:NO];
        textureDesc.usage = MTLTextureUsageShaderRead;
        id<MTLTexture> texture = [device newTextureWithDescriptor:textureDesc];

        // Metal expects data in bytes. uint32_t 0xAABBCCDD -> R=DD, G=CC, B=BB, A=AA (Little Endian)
        [texture replaceRegion:MTLRegionMake2D(0, 0, m_Width, m_Height) 
                   mipmapLevel:0 
                     withBytes:&data 
                   bytesPerRow:4 * m_Width];

        m_Texture = (__bridge_retained void*)texture;
    }

    MetalTexture2D::MetalTexture2D(uint32_t width, uint32_t height, ImageFormat format)
        : m_Width(width), m_Height(height)
    {
        id<MTLDevice> device = (__bridge id<MTLDevice>)MetalRendererAPI::GetDevice();
        
        MTLTextureDescriptor* textureDescriptor = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:ImgFmtToMtlFmt(format) 
                                                                                                     width:width 
                                                                                                    height:height 
                                                                                                    mipmapped:NO];
        
        // allow this texture to be written to by a shader (RenderTarget)
        textureDescriptor.usage = MTLTextureUsageShaderRead | MTLTextureUsageRenderTarget;
        textureDescriptor.storageMode = MTLStorageModePrivate;

        m_Texture = (__bridge_retained void*)[device newTextureWithDescriptor:textureDescriptor];
    }

    MetalTexture2D::~MetalTexture2D()
    {
        if (m_Texture) {
            CFRelease(m_Texture); // Release the bridged object
            m_Texture = nullptr;
        }
        
        // Clean up CPU buffers if they persist
        if (resized_image_16) delete[] resized_image_16;
        if (resized_image_8) delete[] resized_image_8;
        // pixel_data is usually freed by stbi_image_free immediately after upload
    }

    void MetalTexture2D::Bind(uint32_t slot) const
    {
        id<MTLRenderCommandEncoder> encoder = (__bridge id<MTLRenderCommandEncoder>)MetalRendererAPI::GetCurrentEncoder();
        if (encoder && m_Texture) {
            [encoder setFragmentTexture:(__bridge id<MTLTexture>)m_Texture atIndex:slot];
        }
    }

    void MetalTexture2D::UnBind() const
    {
        // Metal doesn't strictly "unbind", setting nil is optional
    }

    void MetalTexture2D::Create16BitTexture(const std::string& path)
    {
        stbi_set_flip_vertically_on_load(1);
        pixel_data_16 = stbi_load_16(path.c_str(), &m_Width, &m_Height, &channels, 0);

        if (pixel_data_16 == nullptr) {
            CN_CORE_ERROR("2D Image Not Found: {0}", path);
            CreateWhiteTexture();
            return;
        }

        id<MTLDevice> device = (__bridge id<MTLDevice>)MetalRendererAPI::GetDevice();
        MTLPixelFormat format = MTLPixelFormatRGBA16Unorm; 
        
        // Metal requires 4-channel alignment for simple uploads usually
        // If channels != 4,  might need a conversion loop here similar to 8-bit below
        // For simplicity assuming 4 here, or rely on STB forcing 4 channels
        // pixel_data_16 = stbi_load_16(..., 4)
        
        MTLTextureDescriptor* desc = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:format 
                                                                                        width:m_Width 
                                                                                       height:m_Height 
                                                                                    mipmapped:YES];
        id<MTLTexture> texture = [device newTextureWithDescriptor:desc];

        void* dataToUpload = resized_image_16 ? (void*)resized_image_16 : (void*)pixel_data_16;
        
        [texture replaceRegion:MTLRegionMake2D(0, 0, m_Width, m_Height)
                   mipmapLevel:0
                     withBytes:dataToUpload
                   bytesPerRow:m_Width * channels * sizeof(unsigned short)];

        m_Texture = (__bridge_retained void*)texture;
        
        GenerateMipmaps();

        if (resized_image_16) { delete[] resized_image_16; resized_image_16 = nullptr; }
        if (pixel_data_16) { stbi_image_free(pixel_data_16); pixel_data_16 = nullptr; }
    }

    void MetalTexture2D::Create8BitsTexture(const std::string& path)
    {
        stbi_set_flip_vertically_on_load(1);
        
        // FORCE 4 CHANNELS (RGBA)
        // Metal does NOT support RGB8 (3 channels) convert to 4 immediately
        int desired_channels = 4; 
        pixel_data_8 = stbi_load(path.c_str(), &m_Width, &m_Height, &channels, desired_channels);

        if (pixel_data_8 == nullptr) {
            CN_CORE_ERROR("2D Image not found: {0}", path);
            CreateWhiteTexture();
            return;
        }
        
        // channels var holds original file channels, but pixel_data_8 is now RGBA (4 bytes)
        
        id<MTLDevice> device = (__bridge id<MTLDevice>)MetalRendererAPI::GetDevice();
        
        MTLTextureDescriptor* desc = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA8Unorm 
                                                                                        width:m_Width 
                                                                                       height:m_Height 
                                                                                    mipmapped:YES];
        id<MTLTexture> texture = [device newTextureWithDescriptor:desc];

        void* dataPtr = resized_image_8 ? (void*)resized_image_8 : (void*)pixel_data_8;

        [texture replaceRegion:MTLRegionMake2D(0, 0, m_Width, m_Height)
                   mipmapLevel:0
                     withBytes:dataPtr
                   bytesPerRow:m_Width * 4]; // Always 4 bytes per pixel now

        m_Texture = (__bridge_retained void*)texture;
        
        GenerateMipmaps();

        if (resized_image_8) { delete[] resized_image_8; resized_image_8 = nullptr; }
        if (pixel_data_8) { stbi_image_free(pixel_data_8); pixel_data_8 = nullptr; }
    }

    void MetalTexture2D::CreateWhiteTexture()
    {
        // Fallback 1x1 White Texture
        uint32_t whiteData = 0xffffffff;
        
        id<MTLDevice> device = (__bridge id<MTLDevice>)MetalRendererAPI::GetDevice();
        MTLTextureDescriptor* desc = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA8Unorm 
                                                                                        width:1 
                                                                                       height:1 
                                                                                    mipmapped:NO];
        id<MTLTexture> texture = [device newTextureWithDescriptor:desc];
        
        [texture replaceRegion:MTLRegionMake2D(0, 0, 1, 1) 
                   mipmapLevel:0 
                   withBytes:&whiteData 
                   bytesPerRow:4];
                   
        m_Texture = (__bridge_retained void*)texture;
    }

    void MetalTexture2D::GenerateMipmaps()
    {
        // transient command buffer just for blitting mipmaps
        id<MTLCommandQueue> queue = (__bridge id<MTLCommandQueue>)MetalRendererAPI::GetCommandQueue();
        id<MTLCommandBuffer> cmdBuffer = [queue commandBuffer];
        id<MTLBlitCommandEncoder> blitEncoder = [cmdBuffer blitCommandEncoder];
        
        [blitEncoder generateMipmapsForTexture:(__bridge id<MTLTexture>)m_Texture];
        [blitEncoder endEncoding];
        
        [cmdBuffer commit];
        [cmdBuffer waitUntilCompleted]; // Wait to ensure texture is ready before use
    }

    // Logic remains identical to CPU version, just handles the buffer pointers
    void MetalTexture2D::Resize_Image(const float& width, const float& height, bool bUse16BitTexture)
    {
        if (bUse16BitTexture)
        {
            if (m_Height > width && m_Width > height)
            {
                resized_image_16 = new unsigned short[(int)width * (int)height * channels];
                stbir_resize_uint16_generic(pixel_data_16, m_Width, m_Height, 0, 
                                            resized_image_16, width, height, 0, 
                                            channels, 0, 0, 
                                            STBIR_EDGE_REFLECT, STBIR_FILTER_BOX, STBIR_COLORSPACE_LINEAR, 0);
                m_Height = height;
                m_Width = width;
            }
        }
        else
        {
            if (m_Height > width && m_Width > height)
            {
                resized_image_8 = new unsigned char[(int)width * (int)height * 4]; // Using 4 channels now
                // Note: Ensure pixel_data_8 is valid before calling this
                if(pixel_data_8) {
                    stbir_resize_uint8(pixel_data_8, m_Width, m_Height, 0, 
                                       resized_image_8, width, height, 0, 
                                       4); // 4 Channels forced
                }
                m_Height = height;
                m_Width = width;
            }
        }
    }



    //////////// cube


    MetalTextureCube::MetalTextureCube(uint32_t width, uint32_t height, ImageFormat format)
        : m_Width(width), m_Height(height)
    {
        id<MTLDevice> device = (__bridge id<MTLDevice>)MetalRendererAPI::GetDevice();

        // Note Metal does NOT support RGB (3-channel) We must use RGBA
        MTLPixelFormat mtlFormat = ImgFmtToMtlFmt(format);
        
        // Cube Descriptor
        MTLTextureDescriptor* desc = [MTLTextureDescriptor textureCubeDescriptorWithPixelFormat:mtlFormat 
                                                                                           size:width 
                                                                                      mipmapped:YES];
        
        // We allow RenderTarget usage so we can render Equirectangular-to-Cubemap later
        desc.usage = MTLTextureUsageShaderRead | MTLTextureUsageRenderTarget;
        desc.storageMode = MTLStorageModePrivate;

        // Create Texture
        m_Texture = (__bridge_retained void*)[device newTextureWithDescriptor:desc];
    }

    void MetalTextureCube::Bind(uint32_t slot) const
    {
        id<MTLRenderCommandEncoder> encoder = (__bridge id<MTLRenderCommandEncoder>)MetalRendererAPI::GetCurrentEncoder();
        
        if (encoder && m_Texture)
        {
            // Bind as a fragment shader texture
            [encoder setFragmentTexture:(__bridge id<MTLTexture>)m_Texture atIndex:slot];
        }
    }

    void MetalTextureCube::UnBind() const
    {
        // Metal doesn't require explicit unbinding, but we can set nil 
        // Usually mostly redundant in modern APIs
    }


    void MetalTextureCube::GenerateMips()
    {
        if (!m_Texture) return;

        // temporary Blit Encoder to generate mipmaps
        id<MTLCommandQueue> queue = (__bridge id<MTLCommandQueue>)MetalRendererAPI::GetCommandQueue();
        id<MTLCommandBuffer> cmdBuffer = [queue commandBuffer];
        cmdBuffer.label = @"Generate Cube Mips";

        id<MTLBlitCommandEncoder> blitEncoder = [cmdBuffer blitCommandEncoder];
        
        [blitEncoder generateMipmapsForTexture:(__bridge id<MTLTexture>)m_Texture];
        
        [blitEncoder endEncoding];
        [cmdBuffer commit];
        
        // wait for it to finish so the texture is ready for use immediately
        [cmdBuffer waitUntilCompleted];
    }
}