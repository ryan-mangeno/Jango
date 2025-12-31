#include "cnpch.h"
#include "OpenGLSSAO.h"
#include "glad/glad.h"
#include "Crimson/Renderer/Terrain.h"

namespace Crimson {
	OpenGLSSAO::OpenGLSSAO(int width, int height)
	{
		CN_PROFILE_FUNCTION()

		SSAOShader = Shader::Create("Crimson_Editor/Assets/Shaders/GLSL/SSAO.glsl");
		GbufferPosition = Shader::Create("Crimson_Editor/Assets/Shaders/GLSL/GBuffer.glsl");
		GbufferPosition_Terrain = Shader::Create("Crimson_Editor/Assets/Shaders/GLSL/GBufferTerrain.glsl");
		GbufferPositionInstanced = Shader::Create("Crimson_Editor/Assets/Shaders/GLSL/GBufferInstanced.glsl");
		SSAOShader_Terrain = Shader::Create("Crimson_Editor/Assets/Shaders/GLSL/SSAO_Terrain.glsl");
		SSAOblurShader = Shader::Create("Crimson_Editor/Assets/Shaders/GLSL/SSAO_Blur.glsl");
		CreateSSAOTexture(width,height);
	}

	OpenGLSSAO::~OpenGLSSAO()
	{
	}

	void OpenGLSSAO::CaptureScene(Scene& scene , Camera& cam)
	{

		CN_PROFILE_FUNCTION()

		glm::vec2 viewport_size = RenderCommand::GetViewportSize();

		//generating random samples, random floats will be [0, 1)
		std::uniform_real_distribution<float> RandomFloats(0.0f, 1.0f);
		std::random_device rd;
		std::default_random_engine generator(rd());

		for (int i = 0; i < RANDOM_SAMPLES_SIZE; i++)
		{
			m_Samples[i] = glm::vec3(
				RandomFloats(generator) * 2.0f - 1.0f,
				RandomFloats(generator) * 2.0f - 1.0f,
				RandomFloats(generator)
			);
			m_Samples[i] = glm::normalize(m_Samples[i]);
			m_Samples[i] *= RandomFloats(generator);

			float scale = static_cast<float>(i) / RANDOM_SAMPLES_SIZE;
			float val = 0.1 * scale * scale + (1.0 - 0.1) * scale * scale;
			m_Samples[i] *= val;
		}


		glBindFramebuffer(GL_DRAW_FRAMEBUFFER, SSAOframebuffer_id);
		glViewport(0, 0, m_width, m_height);

		glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT, GL_RENDERBUFFER, SSAOdepth_id);
		glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, SSAOtexture_id, 0);

		if (glCheckFramebufferStatus(GL_FRAMEBUFFER) != GL_FRAMEBUFFER_COMPLETE)
			CN_CORE_ERROR("SSAO Framebuffer Failed"); 

		glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
		
		SSAOShader->Bind();
		SSAOShader->SetFloat("ScreenWidth", viewport_size.x);
		SSAOShader->SetFloat("ScreenHeight", viewport_size.y);
		SSAOShader->SetMat4("u_ProjectionView", cam.GetProjectionView());		
		SSAOShader->SetFloat3Array("Samples", &m_Samples[0].x, RANDOM_SAMPLES_SIZE);
		SSAOShader->SetMat4("u_projection", cam.GetProjectionMatrix());
		SSAOShader->SetInt("noisetex", NOISE_SLOT);
		SSAOShader->SetInt("depthBuffer", SCENE_DEPTH_SLOT);
		SSAOShader->SetInt("gNormal", G_NORMAL_TEXTURE_SLOT);
		SSAOShader->SetFloat3("u_CamPos", cam.GetCameraPosition());

		RenderQuad();
	
		glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, SSAOblur_id, 0);
		if (glCheckFramebufferStatus(GL_FRAMEBUFFER) != GL_FRAMEBUFFER_COMPLETE)
			CN_CORE_ERROR("SSAO Blur Frame Buffer Failed");

		glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
		
		SSAOblurShader->Bind();
		SSAOblurShader->SetInt("SSAOtex", SSAO_SLOT);
		SSAOblurShader->SetMat4("u_ProjectionView", cam.GetProjectionView());
		SSAOblurShader->SetInt("alpha_texture", ROUGHNESS_SLOT);//for foliage if the isFoliage flag is set to 1 then render the foliage with the help of opacity texture
		
		RenderQuad();

		glBindFramebuffer(GL_DRAW_FRAMEBUFFER, 0);
		glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
		glViewport(0, 0, viewport_size.x, viewport_size.y);
	}
	void OpenGLSSAO::CreateSSAOTexture(int width, int height)
	{

		CN_PROFILE_FUNCTION()

		m_width = width;
		m_height = height;
		glm::vec2 size = RenderCommand::GetViewportSize();

		// ssao frame buffer and texture creation
		glCreateFramebuffers(1, &SSAOframebuffer_id);
		glCreateTextures(GL_TEXTURE_2D, 1, &SSAOtexture_id);
		glBindTexture(GL_TEXTURE_2D, SSAOtexture_id);
		glTexImage2D(GL_TEXTURE_2D, 0, GL_R8, m_width, m_height, 0, GL_RED, GL_UNSIGNED_BYTE, nullptr);

		glGenerateMipmap(GL_TEXTURE_2D);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_R, GL_CLAMP_TO_EDGE);


		// ssao blur creation
		glCreateTextures(GL_TEXTURE_2D, 1, &SSAOblur_id);
		glBindTexture(GL_TEXTURE_2D, SSAOblur_id);

		glTexImage2D(GL_TEXTURE_2D, 0, GL_R8, m_width, m_height, 0, GL_RED, GL_UNSIGNED_BYTE, nullptr);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_R, GL_CLAMP_TO_EDGE);


		// ssao depth buffer gen
		glGenRenderbuffers(1, &SSAOdepth_id);
		glBindRenderbuffer(GL_RENDERBUFFER, SSAOdepth_id);
		glRenderbufferStorage(GL_RENDERBUFFER, GL_DEPTH_COMPONENT, m_width, m_height);

		GLenum buffers[] = { GL_COLOR_ATTACHMENT0 };
		glDrawBuffers(1, buffers);


		// noise texture creation
		std::uniform_real_distribution<float> RandomFloats(0.0f, 1.0f);
		std::default_random_engine generator; 

		std::vector<glm::vec3> noisetexture;
		for (int i = 0; i < 16; i++)
		{
			noisetexture.push_back(glm::vec3(RandomFloats(generator) * 2.0f - 1.0f, RandomFloats(generator) * 2.0f - 1.0f, 0.0f));
		}
		glCreateTextures(GL_TEXTURE_2D, 1, &noisetex_id);
		glBindTexture(GL_TEXTURE_2D, noisetex_id);
		glTexImage2D(GL_TEXTURE_2D, 0, GL_RGB16F, 4, 4, 0, GL_RGB, GL_FLOAT, &noisetexture[0]);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_REPEAT);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_REPEAT);

		glBindTextureUnit(NOISE_SLOT, noisetex_id);
		glBindTextureUnit(SSAO_BLUR_SLOT, SSAOblur_id);
		glBindTextureUnit(SSAO_SLOT, SSAOtexture_id);
	}
	void OpenGLSSAO::RenderScene(Scene& scene , Ref<Shader>& current_shader)
	{
		
	}

	void OpenGLSSAO::RenderQuad()
	{

		CN_PROFILE_FUNCTION()

		glDisable(GL_CULL_FACE);
		glDepthMask(GL_FALSE);

		//auto inv = glm::inverse(proj * glm::mat4(glm::mat3(view)));//get inverse of projection view to convert cannonical view to world space
		static glm::vec4 data[] = 
		{
			glm::vec4(-1,-1,0,1),glm::vec4(0,0,0,0),
			glm::vec4(1,-1,0,1),glm::vec4(1,0,0,0),
			glm::vec4(1,1,0,1),glm::vec4(1,1,0,0),
			glm::vec4(-1,1,0,1),glm::vec4(0,1,0,0)
		};

		Ref<VertexArray> vao = VertexArray::Create();
		Ref<VertexBuffer> vb = VertexBuffer::Create(&data[0].x, sizeof(data));

		static uint32_t i_data[] = { 0,1,2,0,2,3 };
		Ref<IndexBuffer> ib = IndexBuffer::Create(i_data, sizeof(i_data));

		Ref<BufferLayout> bl = std::make_shared<BufferLayout>(); //buffer layout
		bl->push("position", ShaderDataType::Float4);
		bl->push("coordinate", ShaderDataType::Float4);

		vao->AddBuffer(bl, vb);
		vao->SetIndexBuffer(ib);

		RenderCommand::DrawIndex(*vao, GL_TRIANGLES);

		glDepthMask(GL_TRUE);
		glEnable(GL_CULL_FACE);
		glCullFace(GL_BACK);
	}
	void OpenGLSSAO::RenderTerrain(Scene& scene, Ref<Shader>& current_shader1, Ref<Shader>& current_shader2)
	{			
		GbufferPositionInstanced->Bind();
		//Pass a alpha texture in the fragment shader to remove the depth values from the pixels that masked by alpha texture
		GbufferPositionInstanced->SetInt("u_Alpha", ROUGHNESS_SLOT);//'2' is the slot for roughness map (alpha, roughness , AO in RGB) I have explicitely defined it for now
		GbufferPositionInstanced->SetMat4("u_Model", Terrain::m_terrainModelMat);
		GbufferPositionInstanced->SetMat4("u_View", scene.GetCamera()->GetViewMatrix());
		GbufferPositionInstanced->SetMat4("u_Projection", scene.GetCamera()->GetProjectionMatrix());
		GbufferPositionInstanced->SetInt("Noise", PERLIN_NOISE_TEXTURE_SLOT);
		GbufferPositionInstanced->SetFloat("u_Time", Terrain::time);
		glCullFace(GL_BACK);
	}
}