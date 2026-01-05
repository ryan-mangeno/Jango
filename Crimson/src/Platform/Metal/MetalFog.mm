#include "cnpch.h"
#include "MetalFog.h"
#include "glad/glad.h"

namespace Crimson
{

	MetalFog::MetalFog()
		:m_density(0.005),m_gradient(1.3),m_fogStart(60.0f),m_fogEnd(5000)
	{
		m_fogShader = Shader::Create("Crimson_Editor/Assets/Shaders/{API}/PostProcessFog{EXT}");
	}


	MetalFog::MetalFog(float density, float fogStart, float fogEnd, float fogTop, float fogBottom, glm::vec2 ScreenSize)
		: m_density(density), m_gradient(1), m_fogStart(fogStart), m_fogEnd(fogEnd), m_screenSize(ScreenSize)
	{
		CN_PROFILE_FUNCTION()

		m_fogShader = Shader::Create("Crimson_Editor/Assets/Shaders/{API}/PostProcessFog{EXT}");

		glGenFramebuffers(1, &m_framebufferID);
		glBindFramebuffer(GL_FRAMEBUFFER, m_framebufferID);

		glGenTextures(1, &m_textureID);
		glBindTexture(GL_TEXTURE_2D, m_textureID);
		glTexImage2D(GL_TEXTURE_2D, 0, GL_RGB8, m_screenSize.x, m_screenSize.y, 0, GL_RGB, GL_UNSIGNED_BYTE, 0);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);

		glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, m_textureID, 0);
		GLenum buff[] = { GL_COLOR_ATTACHMENT0 };
		glDrawBuffers(1, buff);



		std::array<glm::vec4, 8> data =
		{
			{
				glm::vec4(-1,-1,0,1),
				glm::vec4(0,0,0,0),
				glm::vec4(1,-1,0,1),
				glm::vec4(1,0,0,0),
				glm::vec4(1,1,0,1),
				glm::vec4(1,1,0,0),
				glm::vec4(-1,1,0,1),
				glm::vec4(0,1,0,0)
			}
		};

		m_VAO = VertexArray::Create();
		m_VBO = VertexBuffer::Create(&data[0].x, sizeof(data));

		std::array<uint32_t, 6> i_data = { 0,1,2,0,2,3 };
		m_EBO = IndexBuffer::Create(&i_data[0], sizeof(i_data));

		m_Bl = std::make_shared<BufferLayout>(); //buffer layout

		m_Bl->push("position", ShaderDataType::Float4);
		m_Bl->push("direction", ShaderDataType::Float4);

		m_VAO->AddBuffer(m_Bl, m_VBO);
		m_VAO->SetIndexBuffer(m_EBO);




	}

	MetalFog::~MetalFog()
	{
	}

	void MetalFog::RenderFog(Camera& cam, const glm::vec2& screenSize)
	{

		CN_PROFILE_FUNCTION()

		m_fogShader->Bind();
		m_fogShader->SetInt("u_sceneDepth", SCENE_DEPTH_SLOT);
		m_fogShader->SetInt("u_sceneColor", ORIGINAL_SCENE_TEXTURE_SLOT);
		m_fogShader->SetFloat("u_nearPlane", cam.GetPerspectiveNear());
		m_fogShader->SetFloat("u_farPlane", cam.GetPerspectiveFar());
		m_fogShader->SetFloat("u_density", m_density);
		m_fogShader->SetFloat("u_gradient", m_gradient);
		m_fogShader->SetFloat3("u_fogColor", m_fogColor);
		m_fogShader->SetFloat("u_fogTop", m_fogTop);
		m_fogShader->SetFloat("u_fogEnd", m_fogEnd);
		m_fogShader->SetFloat3("u_sunDir", Renderer3D::m_SunLightDir);
		m_fogShader->SetFloat3("u_ViewDir", cam.GetViewDirection());
		m_fogShader->SetFloat3("u_CamPos", cam.GetCameraPosition());
		m_fogShader->SetMat4("u_Projection", cam.GetProjectionMatrix());
		m_fogShader->SetMat4("u_View", cam.GetViewMatrix());

		glBindFramebuffer(GL_FRAMEBUFFER, m_framebufferID);
		glViewport(0, 0, m_screenSize.x, m_screenSize.y);
		glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
		RenderQuad();
		glBindFramebuffer(GL_FRAMEBUFFER, 0);
		glViewport(0, 0, screenSize.x, screenSize.y);

		glBindTextureUnit(ORIGINAL_SCENE_TEXTURE_SLOT, m_textureID);//update these slotes to capture the post-processing
		glBindTextureUnit(SCENE_TEXTURE_SLOT, m_textureID);

	}


	void MetalFog::RenderQuad()
	{

		CN_PROFILE_FUNCTION()

		//this function renders a quad infront of the camera
		glDisable(GL_CULL_FACE);
		glDepthMask(GL_FALSE);

		RenderCommand::DrawIndex(*m_VAO, GL_TRIANGLES);

		glDepthMask(GL_TRUE);
		glEnable(GL_CULL_FACE);
		glCullFace(GL_BACK);
	}
}
