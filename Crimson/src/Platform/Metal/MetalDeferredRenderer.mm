#include "cnpch.h"
#include "MetalDeferredRenderer.h"
#include "Crimson/Renderer/RenderCommand.h"
#include "Crimson/Renderer/Renderer3D.h"
#include "Crimson/Renderer/Terrain.h"
#include "Crimson/Renderer/Antialiasing.h"
#include "Crimson/Physics/Physics3D.h"
#include "MetalRendererAPI.h"
#include "MetalTexture2D.h" // Reuse your existing texture class

#import <Metal/Metal.h>

namespace Crimson {

    // --- G-Buffer Attachments ---
    // We store these locally in the renderer, just like the OpenGL version stores GLuints
    Ref<MetalTexture2D> MetalDeferredRenderer::m_NormalTexture;
    Ref<MetalTexture2D> MetalDeferredRenderer::m_VelocityTexture;
    Ref<MetalTexture2D> MetalDeferredRenderer::m_AlbedoTexture;
    Ref<MetalTexture2D> MetalDeferredRenderer::m_RoughnessTexture;
    Ref<MetalTexture2D> MetalDeferredRenderer::m_DepthTexture;

    Ref<Shader> MetalDeferredRenderer::m_ForwardPassShader;
    Ref<Shader> MetalDeferredRenderer::m_DefferedPassShader;
    
    int MetalDeferredRenderer::m_Width = 0;
    int MetalDeferredRenderer::m_Height = 0;

	static id<MTLTexture> GetMTL(Ref<MetalTexture2D> tex){
		if(!tex) CN_CORE_ERROR("Error: Input Texture DNE");
		return (__bridge id<MTLTexture>)(tex->GetTexturePointer());
	}

    void MetalDeferredRenderer::Init(int width, int height)
    {
        CN_PROFILE_FUNCTION();

        m_Width = width;
        m_Height = height;

        m_DefferedPassShader = Shader::Create("Crimson_Editor/Assets/Shaders/Metal/DeferredPass.metal");
        m_ForwardPassShader  = Shader::Create("Crimson_Editor/Assets/Shaders/Metal/ForwardPass.metal");

        // Create G-Buffer Textures
        // Normal: RGBA16F
        m_NormalTexture = MakeRef<MetalTexture2D>(width, height, ImageFormat::RGBA16F);
        
        // Velocity: RG16F
        m_VelocityTexture = MakeRef<MetalTexture2D>(width, height, ImageFormat::RG16F);
        
        // Albedo: RGBA8
        m_AlbedoTexture = MakeRef<MetalTexture2D>(width, height, ImageFormat::RGBA8);
        
        // Roughness/Metallic: RGBA8
        m_RoughnessTexture = MakeRef<MetalTexture2D>(width, height, ImageFormat::RGBA8);
        
        // Depth: Depth32F
        m_DepthTexture = MakeRef<MetalTexture2D>(width, height, ImageFormat::DEPTH32F);
        
        CN_CORE_INFO("Metal G-Buffer Initialized");
    }

    void MetalDeferredRenderer::RenderEntities(Scene* scene)
    {
        scene->getRegistry().each([&](auto m_entity)
        {
            Entity Entity(scene, m_entity);
            if (!Entity.GetComponent<StaticMeshComponent>().isFoliage)
            {
                const auto& transform = Entity.GetComponent<TransformComponent>().GetTransform();
                auto& mesh = Entity.GetComponent<StaticMeshComponent>();

                if (Entity.HasComponent<PhysicsComponent>()) {
                    auto& physics_cmp = Entity.GetComponent<PhysicsComponent>();
                    Physics3D::UpdateTransform(Entity.GetComponent<TransformComponent>(), physics_cmp);
                }

                if (Entity.HasComponent<SpriteRenderer>()) {
                    auto& sprite = Entity.GetComponent<SpriteRenderer>();
                    Renderer3D::SetTransperancy(sprite.Transperancy);
                    Renderer3D::DrawMesh(*mesh, transform, sprite.Color * sprite.Emission_Scale, 
                                       sprite.m_WireFrame, sprite.m_Roughness, sprite.m_Metallic, 
                                       m_ForwardPassShader);
                }
                else {
                    Renderer3D::SetTransperancy(1.0f);
                    Renderer3D::DrawMesh(*mesh, transform, Entity.m_DefaultColor, false, 
                                       1.0f, 0.0f, m_ForwardPassShader); 
                }
            }
        });
    }
    
    void MetalDeferredRenderer::CreateBuffers(Scene* scene, bool withWater)
    {
        CN_PROFILE_FUNCTION();

        // Build the G-Buffer Pass manually
        MTLRenderPassDescriptor* passDesc = [MTLRenderPassDescriptor renderPassDescriptor];
        
        // Attachment 0: Normal
        passDesc.colorAttachments[0].texture = GetMTL(m_NormalTexture);
        passDesc.colorAttachments[0].loadAction = MTLLoadActionClear;
        passDesc.colorAttachments[0].storeAction = MTLStoreActionStore;
        passDesc.colorAttachments[0].clearColor = MTLClearColorMake(0, 0, 0, 1);

        // Attachment 1: Velocity
        passDesc.colorAttachments[1].texture = GetMTL(m_VelocityTexture);
        passDesc.colorAttachments[1].loadAction = MTLLoadActionClear;
        passDesc.colorAttachments[1].storeAction = MTLStoreActionStore;
        passDesc.colorAttachments[1].clearColor = MTLClearColorMake(0, 0, 0, 0);

        // Attachment 2: Albedo
        passDesc.colorAttachments[2].texture = GetMTL(m_AlbedoTexture);
        passDesc.colorAttachments[2].loadAction = MTLLoadActionClear;
        passDesc.colorAttachments[2].storeAction = MTLStoreActionStore;
        passDesc.colorAttachments[2].clearColor = MTLClearColorMake(0, 0, 0, 1);

        // Attachment 3: Roughness/Metallic
        passDesc.colorAttachments[3].texture = GetMTL(m_RoughnessTexture);
        passDesc.colorAttachments[3].loadAction = MTLLoadActionClear;
        passDesc.colorAttachments[3].storeAction = MTLStoreActionStore;
        passDesc.colorAttachments[3].clearColor = MTLClearColorMake(0, 0, 0, 1);

        // Depth Attachment
        passDesc.depthAttachment.texture = GetMTL(m_DepthTexture);
        passDesc.depthAttachment.loadAction = MTLLoadActionClear;
        passDesc.depthAttachment.storeAction = MTLStoreActionStore;
        passDesc.depthAttachment.clearDepth = 1.0;

        // start pass
        id<MTLCommandBuffer> cmdBuf = (__bridge id<MTLCommandBuffer>)MetalRendererAPI::GetCurrentCommandBuffer();
        id<MTLRenderCommandEncoder> encoder = [cmdBuf renderCommandEncoderWithDescriptor:passDesc];
        // Store encoder globally so Renderer3D::DrawMesh can use it
        MetalRendererAPI::SetCurrentEncoder((void*)CFBridgingRetain(encoder));
        RenderCommand::SetViewport(m_Width, m_Height);

        // Render Scene
        scene->m_Terrain->RenderTerrain(*scene->GetCamera(), withWater);
        Renderer3D::BeginScene(*scene->GetCamera(), m_ForwardPassShader);
        RenderEntities(scene);

		// end
        Renderer3D::EndScene();
        [encoder endEncoding]; // todo, put this logic into end scene, end scene is empty rn
        CFRelease((__bridge CFTypeRef)encoder);
        MetalRendererAPI::SetCurrentEncoder(nullptr);

        // Update Deferred Shader for next pass
        m_DefferedPassShader->Bind();
        m_DefferedPassShader->SetFloat3("EyePosition", scene->GetCamera()->GetCameraPosition());
    }

    void MetalDeferredRenderer::DeferredPass()
    {
        CN_PROFILE_FUNCTION();

        glm::vec2 viewport = RenderCommand::GetViewportSize();
        RenderCommand::SetViewport(viewport.x, viewport.y);

        glm::vec2 jitter = Antialiasing::GetJitterOffset();

        m_DefferedPassShader->Bind();
        m_DefferedPassShader->SetFloat("jitterX", jitter.x);
        m_DefferedPassShader->SetFloat("jitterY", jitter.y);

        // Bind G-Buffer Textures to Shader Slots
        // SCENE_DEPTH_SLOT etc must match DeferredPass.metal [[texture(N)]] indices
        m_DepthTexture->Bind(SCENE_DEPTH_SLOT);
        m_NormalTexture->Bind(G_NORMAL_TEXTURE_SLOT);
        m_VelocityTexture->Bind(G_VELOCITY_BUFFER_SLOT);
        m_AlbedoTexture->Bind(G_COLOR_TEXTURE_SLOT);
        m_RoughnessTexture->Bind(G_ROUGHNESS_METALLIC_TEXTURE_SLOT);
        
        // Render Full Screen Quad
        RenderCommand::SetDepthTest(false);
        RenderCommand::SetCullFace(false);

        static float quadVertices[] = {
            -1, -1, 0, 1,   0, 0, 0, 0,
             1, -1, 0, 1,   1, 0, 0, 0,
             1,  1, 0, 1,   1, 1, 0, 0,
            -1,  1, 0, 1,   0, 1, 0, 0
        };
        static uint32_t quadIndices[] = { 0, 1, 2, 2, 3, 0 };

        id<MTLDevice> device = (__bridge id<MTLDevice>)MetalRendererAPI::GetDevice();
        id<MTLBuffer> vb = [device newBufferWithBytes:quadVertices length:sizeof(quadVertices) options:MTLResourceStorageModeShared];
        id<MTLBuffer> ib = [device newBufferWithBytes:quadIndices length:sizeof(quadIndices) options:MTLResourceStorageModeShared];

        id<MTLRenderCommandEncoder> encoder = (__bridge id<MTLRenderCommandEncoder>)MetalRendererAPI::GetCurrentEncoder();
        
        if (encoder) {
            [encoder setVertexBuffer:vb offset:0 atIndex:0]; 
            [encoder drawIndexedPrimitives:MTLPrimitiveTypeTriangle 
                                indexCount:6 
                                 indexType:MTLIndexTypeUInt32 
                               indexBuffer:ib 
                         indexBufferOffset:0];
        }

        RenderCommand::SetDepthTest(true);
        RenderCommand::SetCullFace(true);
    }

    uintptr_t MetalDeferredRenderer::GetBuffers(uint32_t bufferInd)
    {
        switch (bufferInd)
        {
            case  0:    return (uintptr_t)m_NormalTexture->GetTexturePointer();
            case  1:    return (uintptr_t)m_VelocityTexture->GetTexturePointer();
            case  2:    return (uintptr_t)m_AlbedoTexture->GetTexturePointer();
            case  3:    return (uintptr_t)m_RoughnessTexture->GetTexturePointer();
            case  4:    return (uintptr_t)m_DepthTexture->GetTexturePointer();
        }
        return 0;
    }
}