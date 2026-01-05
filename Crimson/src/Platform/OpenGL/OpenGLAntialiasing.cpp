#include "cnpch.h"
#include "OpenGLAntialiasing.h"
#include "glad/glad.h"

namespace Crimson
{
	OpenGLAntialiasing::OpenGLAntialiasing(int width, int height)		
	{
		Init(width,height);
	}
	OpenGLAntialiasing::~OpenGLAntialiasing()
	{
	}
	void OpenGLAntialiasing::Init(int width, int height)
	{

		CN_PROFILE_FUNCTION()

		m_Width = width; m_Height = height;
		m_TAA_shader = Shader::Create("Crimson_Editor/Assets/Shaders/{API}/TAA{EXT}");

		glGenFramebuffers(1, &m_fbo);
		glBindFramebuffer(GL_FRAMEBUFFER, m_fbo);

		glGenTextures(1, &m_current_color_buffer_ID);
		glBindTexture(GL_TEXTURE_2D, m_current_color_buffer_ID);
		glTexImage2D(GL_TEXTURE_2D, 0, GL_RGB8, width, height, 0, GL_RGB, GL_UNSIGNED_BYTE, nullptr);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
		glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, m_current_color_buffer_ID, 0);

		const GLenum buff[1] = { GL_COLOR_ATTACHMENT0 };
		glDrawBuffers(1, buff);
		glBindFramebuffer(GL_FRAMEBUFFER, 0);
	}
	void OpenGLAntialiasing::Update()
	{

		CN_PROFILE_FUNCTION()

		m_num_frame++;
		glm::vec2 screenSize = RenderCommand::GetViewportSize();
		if (m_Width != screenSize.x || m_Height != screenSize.y)
		{
			Init(screenSize.x, screenSize.y);
		}
		m_TAA_shader->Bind();
		m_TAA_shader->SetInt("History_Buffer", HISTORY_TEXTURE_SLOT);
		m_TAA_shader->SetInt("Current_Buffer", ORIGINAL_SCENE_TEXTURE_SLOT);
		m_TAA_shader->SetInt("Depth_Buffer", SCENE_DEPTH_SLOT);
		m_TAA_shader->SetInt("gVelocity", G_VELOCITY_BUFFER_SLOT);

		glBindFramebuffer(GL_FRAMEBUFFER, m_fbo);		
		RenderQuad();
		glBindFramebuffer(GL_FRAMEBUFFER, 0);		

		glBindTextureUnit(HISTORY_TEXTURE_SLOT, m_current_color_buffer_ID);
		glBindTextureUnit(ORIGINAL_SCENE_TEXTURE_SLOT, m_current_color_buffer_ID);//update these slotes to capture the post-processing
		glBindTextureUnit(SCENE_TEXTURE_SLOT, m_current_color_buffer_ID);
	}
	void OpenGLAntialiasing::RenderQuad()
	{

		CN_PROFILE_FUNCTION()
		glDisable(GL_CULL_FACE);
		glDepthMask(GL_FALSE);

		const std::array<glm::vec4, 8> data = 
		{
			glm::vec4(-1,-1,0,1),
			glm::vec4(0,0,0,0),
			glm::vec4(1,-1,0,1), 
			glm::vec4(1,0,0,0),
			glm::vec4(1,1,0,1),  
			glm::vec4(1,1,0,0),
			glm::vec4(-1,1,0,1), 
			glm::vec4(0,1,0,0)
		};

		Ref<VertexArray> vao = VertexArray::Create();
		Ref<VertexBuffer> vb = VertexBuffer::Create(&data[0].x, sizeof(data));
		const std::array<uint32_t, 6> i_data = { 0,1,2,0,2,3 };
		Ref<IndexBuffer> ib = IndexBuffer::Create(&i_data[0], sizeof(i_data));

		Ref<BufferLayout> bl = std::make_shared<BufferLayout>(); //buffer layout

		bl->push("position", ShaderDataType::Float4);
		bl->push("direction", ShaderDataType::Float4);

		vao->AddBuffer(bl, vb);
		vao->SetIndexBuffer(ib);

		RenderCommand::DrawIndex(*vao, GL_TRIANGLES);

		glDepthMask(GL_TRUE);//again enable depth testing
		glEnable(GL_CULL_FACE);
		glCullFace(GL_BACK);
	}
}