#include "cnpch.h"
#include "CubeMapEnvironment.h"

#include "Crimson/Renderer/RenderCommand.h"
#include "Crimson/Renderer/Texture.h"
#include "Crimson/Renderer/FrameBuffer.h" 
#include "Crimson/Renderer/Buffer.h"
#include "Crimson/Renderer/Cameras/EditorCamera.h"
#include "Crimson/Core/PrimCodes.h"

#include <glm/gtc/matrix_transform.hpp>

namespace Crimson {

    Ref<Shader> CubeMapEnvironment::Cube_Shader;
    Ref<Shader> CubeMapEnvironment::equirectangularToCube_shader;
    Ref<Shader> CubeMapEnvironment::irradiance_shader;
    Ref<Shader> CubeMapEnvironment::prefilterShader;
    Ref<Shader> CubeMapEnvironment::BRDFSumShader;

    Ref<TextureCube> CubeMapEnvironment::m_EnvironmentMap;
    Ref<TextureCube> CubeMapEnvironment::m_IrradianceMap;
    Ref<TextureCube> CubeMapEnvironment::m_PrefilterMap;
    Ref<Texture2D> CubeMapEnvironment::m_BRDFLUT;
    
    Ref<FrameBuffer> CubeMapEnvironment::m_CaptureFramebuffer;
    Ref<VertexArray> CubeMapEnvironment::m_CubeVAO;

    uint32_t CubeMapEnvironment::captureRes = 512;

    void CubeMapEnvironment::RenderUnitCube() 
    {
        if (!m_CubeVAO)
        {
            float vertices[] = {
                // back face
                -1.0f, -1.0f, -1.0f,  0.0f,  0.0f, -1.0f, 0.0f, 0.0f, 
                 1.0f,  1.0f, -1.0f,  0.0f,  0.0f, -1.0f, 1.0f, 1.0f, 
                 1.0f, -1.0f, -1.0f,  0.0f,  0.0f, -1.0f, 1.0f, 0.0f,          
                 1.0f,  1.0f, -1.0f,  0.0f,  0.0f, -1.0f, 1.0f, 1.0f, 
                -1.0f, -1.0f, -1.0f,  0.0f,  0.0f, -1.0f, 0.0f, 0.0f, 
                -1.0f,  1.0f, -1.0f,  0.0f,  0.0f, -1.0f, 0.0f, 1.0f, 
                // front face
                -1.0f, -1.0f,  1.0f,  0.0f,  0.0f,  1.0f, 0.0f, 0.0f, 
                 1.0f, -1.0f,  1.0f,  0.0f,  0.0f,  1.0f, 1.0f, 0.0f, 
                 1.0f,  1.0f,  1.0f,  0.0f,  0.0f,  1.0f, 1.0f, 1.0f, 
                 1.0f,  1.0f,  1.0f,  0.0f,  0.0f,  1.0f, 1.0f, 1.0f, 
                -1.0f,  1.0f,  1.0f,  0.0f,  0.0f,  1.0f, 0.0f, 1.0f, 
                -1.0f, -1.0f,  1.0f,  0.0f,  0.0f,  1.0f, 0.0f, 0.0f, 
                // left face
                -1.0f,  1.0f,  1.0f, -1.0f,  0.0f,  0.0f, 1.0f, 0.0f, 
                -1.0f,  1.0f, -1.0f, -1.0f,  0.0f,  0.0f, 1.0f, 1.0f, 
                -1.0f, -1.0f, -1.0f, -1.0f,  0.0f,  0.0f, 0.0f, 1.0f, 
                -1.0f, -1.0f, -1.0f, -1.0f,  0.0f,  0.0f, 0.0f, 1.0f, 
                -1.0f, -1.0f,  1.0f, -1.0f,  0.0f,  0.0f, 0.0f, 0.0f, 
                -1.0f,  1.0f,  1.0f, -1.0f,  0.0f,  0.0f, 1.0f, 0.0f, 
                // right face
                 1.0f,  1.0f,  1.0f,  1.0f,  0.0f,  0.0f, 1.0f, 0.0f, 
                 1.0f, -1.0f, -1.0f,  1.0f,  0.0f,  0.0f, 0.0f, 1.0f, 
                 1.0f,  1.0f, -1.0f,  1.0f,  0.0f,  0.0f, 1.0f, 1.0f,          
                 1.0f, -1.0f, -1.0f,  1.0f,  0.0f,  0.0f, 0.0f, 1.0f, 
                 1.0f,  1.0f,  1.0f,  1.0f,  0.0f,  0.0f, 1.0f, 0.0f, 
                 1.0f, -1.0f,  1.0f,  1.0f,  0.0f,  0.0f, 0.0f, 0.0f,     
                // bottom face
                -1.0f, -1.0f, -1.0f,  0.0f, -1.0f,  0.0f, 0.0f, 1.0f, 
                 1.0f, -1.0f, -1.0f,  0.0f, -1.0f,  0.0f, 1.0f, 1.0f, 
                 1.0f, -1.0f,  1.0f,  0.0f, -1.0f,  0.0f, 1.0f, 0.0f, 
                 1.0f, -1.0f,  1.0f,  0.0f, -1.0f,  0.0f, 1.0f, 0.0f, 
                -1.0f, -1.0f,  1.0f,  0.0f, -1.0f,  0.0f, 0.0f, 0.0f, 
                -1.0f, -1.0f, -1.0f,  0.0f, -1.0f,  0.0f, 0.0f, 1.0f, 
                // top face
                -1.0f,  1.0f, -1.0f,  0.0f,  1.0f,  0.0f, 0.0f, 1.0f, 
                 1.0f,  1.0f , 1.0f,  0.0f,  1.0f,  0.0f, 1.0f, 0.0f, 
                 1.0f,  1.0f, -1.0f,  0.0f,  1.0f,  0.0f, 1.0f, 1.0f,     
                 1.0f,  1.0f,  1.0f,  0.0f,  1.0f,  0.0f, 1.0f, 0.0f, 
                -1.0f,  1.0f, -1.0f,  0.0f,  1.0f,  0.0f, 0.0f, 1.0f, 
                -1.0f,  1.0f,  1.0f,  0.0f,  1.0f,  0.0f, 0.0f, 0.0f  
            };

            m_CubeVAO = VertexArray::Create();
            Ref<VertexBuffer> vbo = VertexBuffer::Create(vertices, sizeof(vertices));
            
            Ref<BufferLayout> bl = std::make_shared<BufferLayout>();
            bl->push("a_Position", ShaderDataType::Float3);
            bl->push("a_Normal", ShaderDataType::Float3);
            bl->push("a_TexCoord", ShaderDataType::Float2);
            
            m_CubeVAO->AddBuffer(bl, vbo);
        }

        m_CubeVAO->Bind();
        // need to make
        // RenderCommand::SetCullMode(CullMode::Back); 
        RenderCommand::Draw(*m_CubeVAO);
    }

    void CubeMapEnvironment::Init(const std::string& path)
    {
        CN_PROFILE_FUNCTION()

        Cube_Shader = Shader::Create("Crimson_Editor/Assets/Shaders/{API}/CubeMap{EXT}");
        equirectangularToCube_shader = Shader::Create("Crimson_Editor/Assets/Shaders/{API}/EquirectangularToCube{EXT}");
        irradiance_shader = Shader::Create("Crimson_Editor/Assets/Shaders/{API}/IBL_Irradiance{EXT}");
        prefilterShader = Shader::Create("Crimson_Editor/Assets/Shaders/{API}/IBL_Prefilter{EXT}");
        BRDFSumShader = Shader::Create("Crimson_Editor/Assets/Shaders/{API}/IBL_BRDFSum{EXT}");
        
        CN_CORE_INFO("--- CubeMapEnv Shaders Created ---");

        Ref<Texture2D> hdrTexture = Texture2D::Create(path); 
        if (!hdrTexture) {
            CN_CORE_ERROR("HDR Map Failed to Load!");
            return;
        } else {
            CN_CORE_TRACE("HDR Map Loaded");
        }

        EditorCamera camera;
        camera.SetPerspctive(90.0f, 0.1f, 10.f);
        camera.SetViewportSize(1.0f);
        camera.SetCameraPosition({ 0,0,0 });

        FrameBufferSpecification fbSpec;
        fbSpec.Width = captureRes;
        fbSpec.Height = captureRes;
        // Ensure specification supports format definition
        // fbSpec.Attachments = { FrameBufferTextureFormat::RGBA16F, FrameBufferTextureFormat::Depth }; 
        
        m_CaptureFramebuffer = FrameBuffer::Create(fbSpec);
        
        m_EnvironmentMap = TextureCube::Create(captureRes, captureRes, ImageFormat::RGB16F);

        equirectangularToCube_shader->Bind();
        hdrTexture->Bind(ENV_SLOT);
        equirectangularToCube_shader->SetInt("hdrTexture", ENV_SLOT);

        glm::mat4 captureViews[] =
        {
           glm::lookAt(glm::vec3(0.0f, 0.0f, 0.0f), glm::vec3(1.0f,  0.0f,  0.0f), glm::vec3(0.0f, -1.0f,  0.0f)),
           glm::lookAt(glm::vec3(0.0f, 0.0f, 0.0f), glm::vec3(-1.0f,  0.0f,  0.0f), glm::vec3(0.0f, -1.0f,  0.0f)),
           glm::lookAt(glm::vec3(0.0f, 0.0f, 0.0f), glm::vec3(0.0f,  1.0f,  0.0f), glm::vec3(0.0f,  0.0f,  1.0f)),
           glm::lookAt(glm::vec3(0.0f, 0.0f, 0.0f), glm::vec3(0.0f, -1.0f,  0.0f), glm::vec3(0.0f,  0.0f, -1.0f)),
           glm::lookAt(glm::vec3(0.0f, 0.0f, 0.0f), glm::vec3(0.0f,  0.0f,  1.0f), glm::vec3(0.0f, -1.0f,  0.0f)),
           glm::lookAt(glm::vec3(0.0f, 0.0f, 0.0f), glm::vec3(0.0f,  0.0f, -1.0f), glm::vec3(0.0f, -1.0f,  0.0f))
        };

        m_CaptureFramebuffer->Bind();
        RenderCommand::SetViewport(captureRes, captureRes);
        for (int i = 0; i < 6; i++)
        {
            // need to add this method to FrameBuffer class
            // m_CaptureFramebuffer->SetAttachment(m_EnvironmentMap, 0, i);
            RenderCommand::Clear();
            equirectangularToCube_shader->SetMat4("u_ProjectionView", camera.GetProjectionMatrix() * captureViews[i]);
            RenderUnitCube();           
        }
        
        m_CaptureFramebuffer->UnBind();
        RenderCommand::SetViewport(1920, 1080); 

        m_EnvironmentMap->GenerateMips();
        m_EnvironmentMap->Bind(ENV_SLOT);


        CN_CORE_TRACE("Creating Irradiance Map ...");
        ConstructIrradianceMap(camera.GetProjectionMatrix());
        CN_CORE_INFO("--- Created Irradiance Map ---");
        CN_CORE_TRACE("Creating Specular Map ...");
        CreateSpecularMap(camera.GetProjectionMatrix(), &captureViews[0]);
        CN_CORE_INFO("--- Created Specular Map ---");

    }

    void CubeMapEnvironment::RenderCubeMap(const glm::mat4& view, const glm::mat4& proj, const glm::vec3& view_dir)
    {
        CN_PROFILE_FUNCTION()

        Cube_Shader->Bind();
        m_IrradianceMap->Bind(IRR_ENV_SLOT); 
        Cube_Shader->SetInt("env", IRR_ENV_SLOT);

        RenderQuad(view, proj);
    }

    void CubeMapEnvironment::ConstructIrradianceMap(const glm::mat4& proj)
    {       
        CN_PROFILE_FUNCTION()

        const uint32_t irrMapWidth = 32;
        
        m_IrradianceMap = TextureCube::Create(irrMapWidth, irrMapWidth, ImageFormat::RGB16F);

        m_CaptureFramebuffer->Bind();
        m_CaptureFramebuffer->Resize(irrMapWidth, irrMapWidth);
        RenderCommand::SetViewport(irrMapWidth, irrMapWidth);

        const glm::mat4 captureViews[] =
        {
           glm::lookAt(glm::vec3(0.0f, 0.0f, 0.0f), glm::vec3(1.0f,  0.0f,  0.0f), glm::vec3(0.0f, -1.0f,  0.0f)),
           glm::lookAt(glm::vec3(0.0f, 0.0f, 0.0f), glm::vec3(-1.0f,  0.0f,  0.0f), glm::vec3(0.0f, -1.0f,  0.0f)),
           glm::lookAt(glm::vec3(0.0f, 0.0f, 0.0f), glm::vec3(0.0f,  1.0f,  0.0f), glm::vec3(0.0f,  0.0f,  1.0f)),
           glm::lookAt(glm::vec3(0.0f, 0.0f, 0.0f), glm::vec3(0.0f, -1.0f,  0.0f), glm::vec3(0.0f,  0.0f, -1.0f)),
           glm::lookAt(glm::vec3(0.0f, 0.0f, 0.0f), glm::vec3(0.0f,  0.0f,  1.0f), glm::vec3(0.0f, -1.0f,  0.0f)),
           glm::lookAt(glm::vec3(0.0f, 0.0f, 0.0f), glm::vec3(0.0f,  0.0f, -1.0f), glm::vec3(0.0f, -1.0f,  0.0f))
        };

        irradiance_shader->Bind();
        m_EnvironmentMap->Bind(ENV_SLOT);
        irradiance_shader->SetInt("environmentMap", ENV_SLOT);

        for (int i = 0; i < 6; i++)
        {
            // m_CaptureFramebuffer->SetAttachment(m_IrradianceMap, 0, i);
            RenderCommand::Clear();

            irradiance_shader->SetMat4("u_ProjectionView", proj * captureViews[i]);
            RenderUnitCube();
        }
        
        m_CaptureFramebuffer->UnBind();
    }

    void CubeMapEnvironment::CreateSpecularMap(const glm::mat4& proj, glm::mat4* viewDirs)
    {
        CN_PROFILE_FUNCTION()

        uint32_t dim = 128;
        m_PrefilterMap = TextureCube::Create(dim, dim, ImageFormat::RGB16F);
        m_PrefilterMap->GenerateMips();

        prefilterShader->Bind();
        m_EnvironmentMap->Bind(ENV_SLOT);
        prefilterShader->SetInt("environmentMap", ENV_SLOT);

        m_CaptureFramebuffer->Bind();
        
        uint32_t maxMipLevels = 5;
        for (uint32_t mip = 0; mip < maxMipLevels; ++mip)
        {
            uint32_t mipWidth = static_cast<uint32_t>(dim * std::pow(0.5, mip));
            uint32_t mipHeight = static_cast<uint32_t>(dim * std::pow(0.5, mip));
            
            m_CaptureFramebuffer->Resize(mipWidth, mipHeight);
            RenderCommand::SetViewport(mipWidth, mipHeight);

            float roughness = (float)mip / (float)(maxMipLevels - 1);
            prefilterShader->SetFloat("roughness", roughness);
            
            for (uint32_t i = 0; i < 6; ++i)
            {
                // m_CaptureFramebuffer->SetAttachment(m_PrefilterMap, 0, i, mip);
                RenderCommand::Clear();
                prefilterShader->SetMat4("u_ProjectionView", proj * viewDirs[i]);
                RenderUnitCube();
            }
        }
        m_CaptureFramebuffer->UnBind();

        m_BRDFLUT = Texture2D::Create(captureRes, captureRes, ImageFormat::RG16F); // to fix

        m_CaptureFramebuffer->Bind();
        m_CaptureFramebuffer->Resize(captureRes, captureRes);
        // m_CaptureFramebuffer->SetAttachment(m_BRDFLUT, 0); 

        BRDFSumShader->Bind();
        RenderCommand::SetViewport(captureRes, captureRes);
        RenderCommand::Clear();
        
        RenderQuad();
        m_CaptureFramebuffer->UnBind();
    }

    void CubeMapEnvironment::RenderQuad()
    {
        CN_PROFILE_FUNCTION()

        // RenderCommand::SetCullMode(CullMode::None); 
        // RenderCommand::SetDepthMask(false);

        static Ref<VertexArray> s_QuadVAO = nullptr;
        if (!s_QuadVAO)
        {
            glm::vec4 data[] = {
                glm::vec4(-1,-1,0,1),glm::vec4(0,0,0,0),
                glm::vec4(1,-1,0,1),glm::vec4(1,0,0,0),
                glm::vec4(1,1,0,1),glm::vec4(1,1,0,0),
                glm::vec4(-1,1,0,1),glm::vec4(0,1,0,0)
            };

            s_QuadVAO = VertexArray::Create();
            Ref<VertexBuffer> vb = VertexBuffer::Create(&data[0].x, sizeof(data));
            uint32_t i_data[] = { 0,1,2,0,2,3 };
            Ref<IndexBuffer> ib = IndexBuffer::Create(i_data, sizeof(i_data));

            // FIX: push pattern
            Ref<BufferLayout> bl = std::make_shared<BufferLayout>();
            bl->push("position", ShaderDataType::Float4);
            bl->push("coordinate", ShaderDataType::Float4);

            s_QuadVAO->AddBuffer(bl, vb); 
            s_QuadVAO->SetIndexBuffer(ib);
        }

        s_QuadVAO->Bind();
        RenderCommand::DrawIndex(*s_QuadVAO, CN_TRIANGLES);

        // RenderCommand::SetDepthMask(true);
        // RenderCommand::SetCullMode(CullMode::Back);
    }

    void CubeMapEnvironment::RenderQuad(const glm::mat4& view, const glm::mat4& proj)
    {
        CN_PROFILE_FUNCTION()

        // RenderCommand::SetCullMode(CullMode::None);
        // RenderCommand::SetDepthMask(false);

        glm::mat4 inv = glm::inverse(glm::mat4(glm::mat3(view))) * glm::inverse(proj);

        glm::vec4 data[] = 
        {
            glm::vec4(-1,-1,0,1), inv * glm::vec4(-1,-1,0,1),
            glm::vec4(1,-1,0,1),  inv * glm::vec4(1,-1,0,1),
            glm::vec4(1,1,0,1),   inv * glm::vec4(1,1,0,1),
            glm::vec4(-1,1,0,1),  inv * glm::vec4(-1,1,0,1),
        };

        Ref<VertexArray> vao = VertexArray::Create();
        Ref<VertexBuffer> vb = VertexBuffer::Create(&data[0].x, sizeof(data));

        uint32_t i_data[] = { 0,1,2,0,2,3 };
        Ref<IndexBuffer> ib = IndexBuffer::Create(i_data, sizeof(i_data));

        // FIX: push pattern
        Ref<BufferLayout> bl = std::make_shared<BufferLayout>();
        bl->push("position", ShaderDataType::Float4);
        bl->push("direction", ShaderDataType::Float4);

        vao->AddBuffer(bl, vb); 
        vao->SetIndexBuffer(ib);

        vao->Bind();
        RenderCommand::DrawIndex(*vao, CN_TRIANGLES);

        // RenderCommand::SetDepthMask(true);
        // RenderCommand::SetCullMode(CullMode::Back);
    }
}