#include "cnpch.h"
#include "OpenGLBloom.h"
#include "glad/glad.h"

namespace Crimson {
	int Bloom::NUMBER_OF_MIPS = 7;
	int Bloom::FILTER_RADIUS = 3;
	float Bloom::m_Exposure = 1.0;
	float Bloom::m_BloomAmount = 0.4;
	float Bloom::m_BrightnessThreshold = 0.9;

	OpenGLBloom::OpenGLBloom()
	{
	}
	OpenGLBloom::~OpenGLBloom()
	{
	}
	void OpenGLBloom::InitBloom()
	{


		CN_PROFILE_FUNCTION()

		m_ScreenDimension = m_Dimension;

		m_DownSampleShader = Shader::Create("Assets/Shaders/DownsampleBloom_Shader.glsl");
		m_UpSampleShader = Shader::Create("Assets/Shaders/UpSampleBloom_Shader.glsl");
		BloomToneMapShader = Shader::Create("Assets/Shaders/BloomToneMapping_Shader.glsl");
		ExtractBrightParts = Shader::Create("Assets/Shaders/ExtractHighFrequencyParts_Shader.glsl");

		glGenTextures(1, &m_InputImage);
		glBindTexture(GL_TEXTURE_2D, m_InputImage);

		if (m_Dimension == glm::vec2(0.f, 0.f))
		{
			CN_CORE_ERROR("Pass The Input Texture With the dimension");
		}

		glGenFramebuffers(1, &m_FBO);
		glBindFramebuffer(GL_FRAMEBUFFER, m_FBO);
		glTexImage2D(GL_TEXTURE_2D, 0, GL_R11F_G11F_B10F, m_Dimension.x, m_Dimension.y, 0, GL_RGB, GL_FLOAT, nullptr);

		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);

		//create the various mip textures FOR NOW CREATE 6 MIPS
		for (int i = 0; i < NUMBER_OF_MIPS; i++)
		{
			TextureMip mip;
			mip.dimension = m_Dimension / (float)pow(2.0f,(i+1));
			glGenTextures(1, &mip.texture);
			glBindTexture(GL_TEXTURE_2D, mip.texture);

			glTexImage2D(GL_TEXTURE_2D, 0, GL_R11F_G11F_B10F, (int)mip.dimension.x, (int)mip.dimension.y, 0, GL_RGB, GL_FLOAT, nullptr);

			glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
			glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
			glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
			glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);

			m_MipLevels.push_back(mip);
		}
		unsigned int attachments[1] = { GL_COLOR_ATTACHMENT0 };
		glDrawBuffers(1, attachments);

		glBindFramebuffer(GL_FRAMEBUFFER, 0);
	}
	void OpenGLBloom::DownSample()
	{

		CN_PROFILE_FUNCTION()

		//High Frequency Parts Extraction
		ExtractImageBrightParts();

		m_DownSampleShader->Bind();
		m_DownSampleShader->SetInt("inputImage", SCENE_TEXTURE_SLOT);
		m_DownSampleShader->SetFloat3("ImageRes", { m_Dimension.x,m_Dimension.y,0 }); // I have to Implement the SetFloat2 method ^_^ ;

		glBindFramebuffer(GL_DRAW_FRAMEBUFFER, m_FBO);

		for (int i = 0; i < NUMBER_OF_MIPS; i++)
		{
			glViewport(0, 0, m_MipLevels[i].dimension.x, m_MipLevels[i].dimension.y);
			glFramebufferTexture2D(GL_DRAW_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, m_MipLevels[i].texture, 0);
			if (glCheckFramebufferStatus(GL_FRAMEBUFFER) != GL_FRAMEBUFFER_COMPLETE)
			{
				CN_CORE_INFO("Downsample Frame Buffer Failed");
			}

			RenderQuad();

			glBindTextureUnit(SCENE_TEXTURE_SLOT, m_MipLevels[i].texture);
			//m_DownSampleShader->SetInt("inputImage", SCENE_TEXTURE_SLOT);
			m_DownSampleShader->SetFloat3("ImageRes", { m_MipLevels[i].dimension.x,m_MipLevels[i].dimension.y,0 }); // I have to Implement the SetFloat2 method
		}
		glBindFramebuffer(GL_DRAW_FRAMEBUFFER, 0);

	}

	void OpenGLBloom::UpSample()
	{

		CN_PROFILE_FUNCTION()

		glEnable(GL_BLEND);
		glBlendFunc(GL_ONE, GL_ONE);
		glBlendEquation(GL_FUNC_ADD);
		m_UpSampleShader->Bind();
		m_UpSampleShader->SetInt("inputImage", SCENE_TEXTURE_SLOT);
		m_UpSampleShader->SetFloat("FilterRadius", FILTER_RADIUS);

		glBindFramebuffer(GL_DRAW_FRAMEBUFFER, m_FBO);

		for (int i = NUMBER_OF_MIPS - 1; i > 0; i--)
		{
			auto& mip = m_MipLevels[i];
			auto& next_mip = m_MipLevels[i - 1];

			m_UpSampleShader->SetFloat3("ImageRes", {mip.dimension.x,mip.dimension.y,0});
			glBindTextureUnit(SCENE_TEXTURE_SLOT, mip.texture);

			glViewport(0, 0, next_mip.dimension.x, next_mip.dimension.y);
			glFramebufferTexture2D(GL_DRAW_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, next_mip.texture, 0);
			RenderQuad();
		}

		// resetting gl states
		glBindFramebuffer(GL_DRAW_FRAMEBUFFER, 0);
		glDisable(GL_BLEND);
		glEnable(GL_BLEND);
		glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);

	}
	void OpenGLBloom::Update(TimeStep ts)
	{

		CN_PROFILE_FUNCTION()

		BloomToneMapShader->Bind();
		BloomToneMapShader->SetInt("inputImage", SCENE_TEXTURE_SLOT);
		BloomToneMapShader->SetInt("OriginalImage", ORIGINAL_SCENE_TEXTURE_SLOT);
		BloomToneMapShader->SetFloat("exposure", Bloom::m_Exposure);
		BloomToneMapShader->SetFloat("BloomAmount", Bloom::m_BloomAmount);

		glViewport(0, 0, m_Dimension.x, m_Dimension.y);
		RenderRotatedQuad(); //flip the final Image after rendering
	}

	void OpenGLBloom::RenderRotatedQuad () {

		glDisable(GL_CULL_FACE);
		glDepthMask(GL_FALSE);

		//quad is rotated by 180 deg by x axis to correct the image orientation
		const std::array<glm::vec4, 8> data =
		{
			glm::vec4(-1,-1,0,1),
			glm::vec4(0,1,0,0),
			glm::vec4(1,-1,0,1), 
			glm::vec4(1,1,0,0),
			glm::vec4(1,1,0,1),  
			glm::vec4(1,0,0,0),
			glm::vec4(-1,1,0,1), 
			glm::vec4(0,0,0,0)
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

		RenderCommand::DrawIndex(*vao);

		glDepthMask(GL_TRUE);
		glEnable(GL_CULL_FACE);
		glCullFace(GL_BACK);
	}

	void OpenGLBloom::RenderQuad()
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

		RenderCommand::DrawIndex(*vao);

		glDepthMask(GL_TRUE);
		glEnable(GL_CULL_FACE);
		glCullFace(GL_BACK);
	}
	void OpenGLBloom::ExtractImageBrightParts()
	{

		CN_PROFILE_FUNCTION()

		ExtractBrightParts->Bind();
		ExtractBrightParts->SetInt("inputImage", SCENE_TEXTURE_SLOT);
		ExtractBrightParts->SetFloat("BightnessThreshold", Bloom::m_BrightnessThreshold);
		
		glBindFramebuffer(GL_DRAW_FRAMEBUFFER, m_FBO);
		glViewport(0, 0, m_ScreenDimension.x, m_ScreenDimension.y);
		glFramebufferTexture2D(GL_DRAW_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, m_InputImage, 0);
		
		RenderQuad();

		glBindFramebuffer(GL_DRAW_FRAMEBUFFER, 0);
		glBindTextureUnit(SCENE_TEXTURE_SLOT, m_InputImage);
		ExtractBrightParts->UnBind();
	}
}