#include "cnpch.h"
#include "MetalShadows.h"
#include "MetalRendererAPI.h"
#include "Crimson/Renderer/Renderer3D.h"
#include "Crimson/Renderer/RenderCommand.h"
#include "Crimson/Renderer/Terrain.h"
#include "Crimson/Renderer/FoliageRenderer.h"

#import <Metal/Metal.h>

namespace Crimson {

    int Shadows::Cascade_level = 0;
    float Shadows::m_lamda = 0.1;

    MetalShadows::MetalShadows()
        : m_width(4096.f), m_height(4096.f)
    {
    }

    MetalShadows::MetalShadows(const float& width, const float& height)
        : m_width(width / MAX_CASCADES), m_height(height / MAX_CASCADES)
    {
        // Load Metal Shaders
        shadow_shader = Shader::Create("Crimson_Editor/Assets/Shaders/{API}/Shadow{EXT}");
        terrain_shadowShader = Shader::Create("Crimson_Editor/Assets/Shaders/{API}/TerrainShadow{EXT}");
        shadow_shaderInstanced = Shader::Create("Crimson_Editor/Assets/Shaders/{API}/ShadowInstanced{EXT}");

        CreateShdowMap();
    }

    MetalShadows::~MetalShadows()
    {
        for (int i = 0; i < MAX_CASCADES; i++) {
            if (depth_id[i]) CFRelease((void*)(uintptr_t)depth_id[i]);
        }
    }

    void MetalShadows::CreateShdowMap()
    {
        CN_PROFILE_FUNCTION();

        id<MTLDevice> device = (__bridge id<MTLDevice>)MetalRendererAPI::GetDevice();

        MTLTextureDescriptor* desc = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatDepth32Float 
                                                                                        width:(NSUInteger)m_width 
                                                                                       height:(NSUInteger)m_height 
                                                                                    mipmapped:NO];
        // Must be RenderTarget (to write depth) and ShaderRead (to sample in DeferredPass)
        desc.usage = MTLTextureUsageRenderTarget | MTLTextureUsageShaderRead;
        desc.storageMode = MTLStorageModePrivate;

        for (int i = 0; i < MAX_CASCADES; i++)
        {
            // Match OpenGL logic: resolution grows per cascade
            // "m_width*(i+1)"
            desc.width = (NSUInteger)(m_width * (i + 1));
            desc.height = (NSUInteger)(m_height * (i + 1));

            id<MTLTexture> texture = [device newTextureWithDescriptor:desc];
            texture.label = [NSString stringWithFormat:@"ShadowMap_Cascade_%d", i];
            
            // Store as uint32_t handle
            depth_id[i] = (uint32_t)(uintptr_t)CFBridgingRetain(texture);
        }
    }

    void MetalShadows::RenderShadows(Scene& scene, const glm::vec3& LightPosition, Camera& cam)
    {
        CN_PROFILE_FUNCTION();

        PrepareShadowProjectionMatrix(cam, LightPosition);

        shadow_shader->Bind();

        for (int i = 0; i < MAX_CASCADES; i++) 
        {
            glm::mat4 LightProjection = m_ShadowProjection[i] * LightView[i]; 

            shadow_shader->SetMat4("LightProjection", LightProjection);
            // In Metal, "u_Alpha" usually implies binding a texture. If using slots:
            // shadow_shader->SetInt("u_Alpha", ROUGHNESS_SLOT); 

            // Begin Render Pass
            MetalRendererAPI::FlushEncoder();
            
            MTLRenderPassDescriptor* passDesc = [MTLRenderPassDescriptor renderPassDescriptor];
            passDesc.depthAttachment.texture = (__bridge id<MTLTexture>)(void*)(uintptr_t)depth_id[i];
            passDesc.depthAttachment.loadAction = MTLLoadActionClear;
            passDesc.depthAttachment.storeAction = MTLStoreActionStore;
            passDesc.depthAttachment.clearDepth = 1.0;

            id<MTLCommandBuffer> cmdBuf = (__bridge id<MTLCommandBuffer>)MetalRendererAPI::GetCurrentCommandBuffer();
            id<MTLRenderCommandEncoder> encoder = [cmdBuf renderCommandEncoderWithDescriptor:passDesc];
            MetalRendererAPI::SetCurrentEncoder((void*)CFBridgingRetain(encoder));

            // Set Viewport
            MTLViewport vp = { 0.0, 0.0, (double)(m_width * (i+1)), (double)(m_height * (i+1)), 0.0, 1.0 };
            [encoder setViewport:vp];
            
            // Set Culling (Back Face)
            [encoder setCullMode:MTLCullModeBack];

            // Draw Entities
            scene.getRegistry().each([&](auto m_entity)
            {
                Entity Entity(&scene, m_entity);
                
                int isFoliageVal = Entity.GetComponent<StaticMeshComponent>().isFoliage ? 1 : 0;
                shadow_shader->SetInt("isFoliage", isFoliageVal); 

                const auto& transform = Entity.GetComponent<TransformComponent>().GetTransform();
                shadow_shader->SetMat4("u_Model", transform);

                auto& mesh = Entity.GetComponent<StaticMeshComponent>();
                
                glm::vec4 color = Entity.m_DefaultColor;
                if (Entity.HasComponent<SpriteRenderer>()) {
                    color = Entity.GetComponent<SpriteRenderer>().Color;
                }
                
                // Draw Mesh (Depth Only)
                Renderer3D::DrawMesh(*mesh, transform, color, false, 0, 0, shadow_shader);
            });

            // End Pass
            [encoder endEncoding];
            CFRelease((__bridge CFTypeRef)encoder);
            MetalRendererAPI::SetCurrentEncoder(nullptr);
        }
    }

    void MetalShadows::RenderTerrainShadows(Scene& scene, const glm::vec3& LightPosition, Camera& cam)
    {
        CN_PROFILE_FUNCTION();
        
        PrepareShadowProjectionMatrix(cam, LightPosition);

        for (int i = 0; i < MAX_CASCADES; i++)
        {
            glm::mat4 LightProjection = m_ShadowProjection[i] * LightView[i];

            // Start Pass
            MetalRendererAPI::FlushEncoder();
            
            MTLRenderPassDescriptor* passDesc = [MTLRenderPassDescriptor renderPassDescriptor];
            passDesc.depthAttachment.texture = (__bridge id<MTLTexture>)(void*)(uintptr_t)depth_id[i];
            passDesc.depthAttachment.loadAction = MTLLoadActionClear;
            passDesc.depthAttachment.storeAction = MTLStoreActionStore;
            passDesc.depthAttachment.clearDepth = 1.0;

            id<MTLCommandBuffer> cmdBuf = (__bridge id<MTLCommandBuffer>)MetalRendererAPI::GetCurrentCommandBuffer();
            id<MTLRenderCommandEncoder> encoder = [cmdBuf renderCommandEncoderWithDescriptor:passDesc];
            MetalRendererAPI::SetCurrentEncoder((void*)CFBridgingRetain(encoder));

            MTLViewport vp = { 0.0, 0.0, (double)(m_width * (i+1)), (double)(m_height * (i+1)), 0.0, 1.0 };
            [encoder setViewport:vp];

            // Render Terrain
            terrain_shadowShader->Bind();
            terrain_shadowShader->SetMat4("LightProjection", LightProjection);
            terrain_shadowShader->SetFloat("HEIGHT_SCALE", Terrain::HeightScale);
            terrain_shadowShader->SetMat4("u_Model", Terrain::m_terrainModelMat);
            terrain_shadowShader->SetMat4("u_View", cam.GetViewMatrix());
            
            // Bind HeightMap manually or via RenderCommand
            // terrain_shadowShader->SetInt("u_HeightMap", HEIGHT_MAP_TEXTURE_SLOT);

            [encoder setCullMode:MTLCullModeFront]; 
            
            // Draw Terrain 
            RenderCommand::DrawArrays(*Terrain::m_terrainVertexArray, Terrain::terrainData.size()); 

            [encoder setCullMode:MTLCullModeBack];

            // Render Entities (Same as RenderShadows but inside this loop)
            shadow_shader->Bind();
            shadow_shader->SetMat4("LightProjection", LightProjection);

            scene.getRegistry().each([&](auto m_entity)
            {
                Entity Entity(&scene, m_entity);
                int isFoliageVal = Entity.GetComponent<StaticMeshComponent>().isFoliage ? 1 : 0;
                shadow_shader->SetInt("isFoliage", isFoliageVal);

                const auto& transform = Entity.GetComponent<TransformComponent>().GetTransform();
                shadow_shader->SetMat4("u_Model", transform);
                auto& mesh = Entity.GetComponent<StaticMeshComponent>();

                glm::vec4 color = Entity.m_DefaultColor;
                if (Entity.HasComponent<SpriteRenderer>()) {
                    color = Entity.GetComponent<SpriteRenderer>().Color;
                }
                Renderer3D::DrawMesh(*mesh, transform, color, false, 0, 0, shadow_shader);
            });

            // Render Foliage Instanced
            shadow_shaderInstanced->Bind();
            shadow_shaderInstanced->SetMat4("LightProjection", LightProjection);
            shadow_shaderInstanced->SetMat4("u_Model", Terrain::m_terrainModelMat);
            
            [encoder setCullMode:MTLCullModeNone]; 
            
            for (Foliage* foliage : Foliage::foliageObjects)
            {
                if (foliage->bCanCastShadow) 
                {
                    foliage->RenderFoliage(shadow_shaderInstanced);
                }
            }
            [encoder setCullMode:MTLCullModeBack];

            [encoder endEncoding];
            CFRelease((__bridge CFTypeRef)encoder);
            MetalRendererAPI::SetCurrentEncoder(nullptr);
        }
    }

    void MetalShadows::RenderFoliageShadows(LoadMesh* mesh, uint32_t bufferID, int numMeshes, const glm::vec3& LightPosition, Camera& cam)
    {
        CN_PROFILE_FUNCTION();

        PrepareShadowProjectionMatrix(cam, LightPosition);

        shadow_shaderInstanced->Bind();
        for (int i = 0; i < MAX_CASCADES; i++)
        {
            glm::mat4 LightProjection = m_ShadowProjection[i] * LightView[i]; 
            shadow_shaderInstanced->SetMat4("LightProjection", LightProjection);
            shadow_shaderInstanced->SetMat4("u_Model", Terrain::m_terrainModelMat);

            MetalRendererAPI::FlushEncoder();
            
            MTLRenderPassDescriptor* passDesc = [MTLRenderPassDescriptor renderPassDescriptor];
            passDesc.depthAttachment.texture = (__bridge id<MTLTexture>)(void*)(uintptr_t)depth_id[i];
            passDesc.depthAttachment.loadAction = MTLLoadActionClear;
            passDesc.depthAttachment.storeAction = MTLStoreActionStore;
            passDesc.depthAttachment.clearDepth = 1.0;

            id<MTLCommandBuffer> cmdBuf = (__bridge id<MTLCommandBuffer>)MetalRendererAPI::GetCurrentCommandBuffer();
            id<MTLRenderCommandEncoder> encoder = [cmdBuf renderCommandEncoderWithDescriptor:passDesc];
            MetalRendererAPI::SetCurrentEncoder((void*)CFBridgingRetain(encoder));

            MTLViewport vp = { 0.0, 0.0, (double)m_width, (double)m_height, 0.0, 1.0 };
            [encoder setViewport:vp];

            Renderer3D::InstancedFoliageData(*mesh, bufferID);

            [encoder endEncoding];
            CFRelease((__bridge CFTypeRef)encoder);
            MetalRendererAPI::SetCurrentEncoder(nullptr);
        }
    }

    void MetalShadows::SetShadowMapResolution(const float& width, float height)
    {
        m_width = width;
        m_height = height;
        for (int i = 0; i < MAX_CASCADES; i++) {
            if (depth_id[i]) {
                CFRelease((void*)(uintptr_t)depth_id[i]);
                depth_id[i] = 0;
            }
        }
        CreateShdowMap();
    }

    void MetalShadows::PassShadowUniforms(Camera& cam, Ref<Shader> rendering_shader)
    {
        rendering_shader->Bind();
        
        std::vector<glm::mat4> LightProj_Matrices(MAX_CASCADES);
		
        for (int i = 0; i < MAX_CASCADES; i++)
			LightProj_Matrices[i] = m_ShadowProjection[i] * LightView[i];
		
        rendering_shader->SetMat4("MatrixShadow", LightProj_Matrices[0], MAX_CASCADES);
        rendering_shader->SetFloatArray("Ranges", Ranges[0], MAX_CASCADES);
        
        rendering_shader->SetMat4("u_View", cam.GetViewMatrix());
        rendering_shader->SetMat4("u_Projection", cam.GetProjectionMatrix());
        
        // Needed for DeferredPass.metal reconstruction
        rendering_shader->SetMat4("u_InverseView", glm::inverse(cam.GetViewMatrix()));
        rendering_shader->SetMat4("u_InverseProjection", glm::inverse(cam.GetProjectionMatrix()));

        // Bind Textures to Slots 6, 7, 8, 9
        id<MTLRenderCommandEncoder> encoder = (__bridge id<MTLRenderCommandEncoder>)MetalRendererAPI::GetCurrentEncoder();
        if (encoder)
        {
            for(int i=0; i<4; i++) {
                if (i < MAX_CASCADES && depth_id[i] != 0) {
                    [encoder setFragmentTexture:(__bridge id<MTLTexture>)(void*)(uintptr_t)depth_id[i] 
                                        atIndex:6 + i];
                }
            }
        }
    }

    void MetalShadows::PrepareShadowProjectionMatrix(Camera& camera, const glm::vec3& LightPosition)
    {
        CN_PROFILE_FUNCTION();

        m_ShadowProjection.clear();

        constexpr float NearPlane = 1.0f;
        constexpr float FarPlane = 800.0f;
        Ranges.resize(MAX_CASCADES + 1);
        Ranges[0] = NearPlane;
        Ranges[MAX_CASCADES] = FarPlane;
        
        for (int i = 1; i < MAX_CASCADES; i++)
        {
            float uniform_split = ((FarPlane - NearPlane) / MAX_CASCADES) * (i);
            float log_split = NearPlane * pow((FarPlane / NearPlane), i / (float)MAX_CASCADES);
            float practical = m_lamda * uniform_split + (1 - m_lamda) * log_split;
            Ranges[i] = practical;
        }
        
        // METAL CLIP CORRECTION [0,1]
        glm::mat4 zClipFix = glm::mat4(1.0f);
        zClipFix[2][2] = 0.5f; 
        zClipFix[3][2] = 0.5f; 

        for (int i = 1; i <= MAX_CASCADES; i++)
        {
            float m_NearPlane = Ranges[i - 1];
            float m_FarPlane = Ranges[i];

            m_Camera_Projection = glm::perspective(glm::radians(camera.GetVerticalFOV()), camera.GetAspectRatio(), NearPlane, m_FarPlane );
            
            glm::vec3 center = glm::vec3(0.0f);
            glm::vec4 frustum_corners[8] = 
            {
                glm::vec4(-1.0f,  1.0f, -1.0f, 1.0f),
                glm::vec4(1.0f,  1.0f, -1.0f, 1.0f),
                glm::vec4(1.0f, -1.0f, -1.0f, 1.0f),
                glm::vec4(-1.0f, -1.0f, -1.0f, 1.0f),
                glm::vec4(-1.0f,  1.0f,  1.0f, 1.0f),
                glm::vec4(1.0f,  1.0f,  1.0f, 1.0f),
                glm::vec4(1.0f, -1.0f,  1.0f, 1.0f),
                glm::vec4(-1.0f, -1.0f,  1.0f, 1.0f),
            };

            const glm::mat4& camera_view = camera.GetViewMatrix();
            glm::mat4 pv_inverse = glm::inverse(camera_view) * glm::inverse(m_Camera_Projection);
            for (int j = 0; j < 8; j++)
            {
                glm::vec4 p = pv_inverse * frustum_corners[j];
                frustum_corners[j] = p / p.w;
                center += glm::vec3(frustum_corners[j]);
            }
            center /= 8.0f;

            LightView[i-1] = glm::lookAt(center, center + glm::normalize(LightPosition), { 0.0,1.0,0.0 });

            glm::mat4 matrix_lv = LightView[i - 1];
            float min_x = std::numeric_limits<float>::max();
            float max_x = std::numeric_limits<float>::lowest();
            float min_y = std::numeric_limits<float>::max();
            float max_y = std::numeric_limits<float>::lowest();
            float min_z = std::numeric_limits<float>::max();
            float max_z = std::numeric_limits<float>::lowest();

            for (int j = 0; j < 8; j++)
            {
                glm::vec4 corner = matrix_lv * frustum_corners[j];
                corner /= corner.w;

                min_x = std::min(min_x, corner.x);
                max_x = std::max(max_x, corner.x);
                min_y = std::min(min_y, corner.y);
                max_y = std::max(max_y, corner.y);
                min_z = std::min(min_z, corner.z);
                max_z = std::max(max_z, corner.z);
            }
            
            static constexpr float zMult = 100.0f;
            if (min_z < 0) min_z *= zMult; else min_z /= zMult;
            if (max_z < 0) max_z /= zMult; else max_z *= zMult;
            
            glm::mat4 orthoProj = glm::ortho(min_x, max_x, min_y, max_y, min_z, max_z);
            
            m_ShadowProjection.push_back(zClipFix * orthoProj);
        }
    }
}