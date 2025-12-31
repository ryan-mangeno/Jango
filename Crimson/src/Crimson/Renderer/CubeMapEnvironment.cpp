#include "cnpch.h"
#include "CubeMapEnvironment.h"
#include "Crimson/Renderer/Cameras/EditorCamera.h"
#include "glad/glad.h"
#include "stb_image.h"
#include "stb_image_resize.h"

namespace Crimson {
	Ref<Shader> CubeMapEnvironment::Cube_Shader, CubeMapEnvironment::equirectangularToCube_shader;
	Ref<Shader> CubeMapEnvironment::irradiance_shader, CubeMapEnvironment::prefilterShader, CubeMapEnvironment::BRDFSumShader;
	uint32_t CubeMapEnvironment::irradiance_map_id = 0, CubeMapEnvironment::framebuffer_id = 0, CubeMapEnvironment::hdrMapID = 0,
		CubeMapEnvironment::renderBuffer_id = 0, CubeMapEnvironment::framebuffer_id2 = 0, CubeMapEnvironment::tex_id = 0;
	uint32_t CubeMapEnvironment::captureRes = 512;

	auto RenderUnitCube = []() {
		uint32_t cubeVAO = 0;
		uint32_t cubeVBO = 0;
		glDisable(GL_CULL_FACE);
		//glDepthMask(GL_FALSE);
		if (cubeVBO == 0) {
			const float vertices[] = {
				// back face
				-1.0f, -1.0f, -1.0f,  0.0f,  0.0f, -1.0f, 0.0f, 0.0f, // bottom-left
				 1.0f,  1.0f, -1.0f,  0.0f,  0.0f, -1.0f, 1.0f, 1.0f, // top-right
				 1.0f, -1.0f, -1.0f,  0.0f,  0.0f, -1.0f, 1.0f, 0.0f, // bottom-right         
				 1.0f,  1.0f, -1.0f,  0.0f,  0.0f, -1.0f, 1.0f, 1.0f, // top-right
				-1.0f, -1.0f, -1.0f,  0.0f,  0.0f, -1.0f, 0.0f, 0.0f, // bottom-left
				-1.0f,  1.0f, -1.0f,  0.0f,  0.0f, -1.0f, 0.0f, 1.0f, // top-left
				// front face
				-1.0f, -1.0f,  1.0f,  0.0f,  0.0f,  1.0f, 0.0f, 0.0f, // bottom-left
				 1.0f, -1.0f,  1.0f,  0.0f,  0.0f,  1.0f, 1.0f, 0.0f, // bottom-right
				 1.0f,  1.0f,  1.0f,  0.0f,  0.0f,  1.0f, 1.0f, 1.0f, // top-right
				 1.0f,  1.0f,  1.0f,  0.0f,  0.0f,  1.0f, 1.0f, 1.0f, // top-right
				-1.0f,  1.0f,  1.0f,  0.0f,  0.0f,  1.0f, 0.0f, 1.0f, // top-left
				-1.0f, -1.0f,  1.0f,  0.0f,  0.0f,  1.0f, 0.0f, 0.0f, // bottom-left
				// left face
				-1.0f,  1.0f,  1.0f, -1.0f,  0.0f,  0.0f, 1.0f, 0.0f, // top-right
				-1.0f,  1.0f, -1.0f, -1.0f,  0.0f,  0.0f, 1.0f, 1.0f, // top-left
				-1.0f, -1.0f, -1.0f, -1.0f,  0.0f,  0.0f, 0.0f, 1.0f, // bottom-left
				-1.0f, -1.0f, -1.0f, -1.0f,  0.0f,  0.0f, 0.0f, 1.0f, // bottom-left
				-1.0f, -1.0f,  1.0f, -1.0f,  0.0f,  0.0f, 0.0f, 0.0f, // bottom-right
				-1.0f,  1.0f,  1.0f, -1.0f,  0.0f,  0.0f, 1.0f, 0.0f, // top-right
				// right face
				 1.0f,  1.0f,  1.0f,  1.0f,  0.0f,  0.0f, 1.0f, 0.0f, // top-left
				 1.0f, -1.0f, -1.0f,  1.0f,  0.0f,  0.0f, 0.0f, 1.0f, // bottom-right
				 1.0f,  1.0f, -1.0f,  1.0f,  0.0f,  0.0f, 1.0f, 1.0f, // top-right         
				 1.0f, -1.0f, -1.0f,  1.0f,  0.0f,  0.0f, 0.0f, 1.0f, // bottom-right
				 1.0f,  1.0f,  1.0f,  1.0f,  0.0f,  0.0f, 1.0f, 0.0f, // top-left
				 1.0f, -1.0f,  1.0f,  1.0f,  0.0f,  0.0f, 0.0f, 0.0f, // bottom-left     
				// bottom face
				-1.0f, -1.0f, -1.0f,  0.0f, -1.0f,  0.0f, 0.0f, 1.0f, // top-right
				 1.0f, -1.0f, -1.0f,  0.0f, -1.0f,  0.0f, 1.0f, 1.0f, // top-left
				 1.0f, -1.0f,  1.0f,  0.0f, -1.0f,  0.0f, 1.0f, 0.0f, // bottom-left
				 1.0f, -1.0f,  1.0f,  0.0f, -1.0f,  0.0f, 1.0f, 0.0f, // bottom-left
				-1.0f, -1.0f,  1.0f,  0.0f, -1.0f,  0.0f, 0.0f, 0.0f, // bottom-right
				-1.0f, -1.0f, -1.0f,  0.0f, -1.0f,  0.0f, 0.0f, 1.0f, // top-right
				// top face
				-1.0f,  1.0f, -1.0f,  0.0f,  1.0f,  0.0f, 0.0f, 1.0f, // top-left
				 1.0f,  1.0f , 1.0f,  0.0f,  1.0f,  0.0f, 1.0f, 0.0f, // bottom-right
				 1.0f,  1.0f, -1.0f,  0.0f,  1.0f,  0.0f, 1.0f, 1.0f, // top-right     
				 1.0f,  1.0f,  1.0f,  0.0f,  1.0f,  0.0f, 1.0f, 0.0f, // bottom-right
				-1.0f,  1.0f, -1.0f,  0.0f,  1.0f,  0.0f, 0.0f, 1.0f, // top-left
				-1.0f,  1.0f,  1.0f,  0.0f,  1.0f,  0.0f, 0.0f, 0.0f  // bottom-left        
			};

			glGenVertexArrays(1, &cubeVAO);
			glGenBuffers(1, &cubeVBO);
			// fill buffer
			glBindBuffer(GL_ARRAY_BUFFER, cubeVBO);
			glBufferData(GL_ARRAY_BUFFER, sizeof(vertices), vertices, GL_STATIC_DRAW);
			// link vertex attributes
			glBindVertexArray(cubeVAO);
			glEnableVertexAttribArray(0);
			glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 8 * sizeof(float), (void*)0);
			glEnableVertexAttribArray(1);
			glVertexAttribPointer(1, 3, GL_FLOAT, GL_FALSE, 8 * sizeof(float), (void*)(3 * sizeof(float)));
			glEnableVertexAttribArray(2);
			glVertexAttribPointer(2, 2, GL_FLOAT, GL_FALSE, 8 * sizeof(float), (void*)(6 * sizeof(float)));
			glBindBuffer(GL_ARRAY_BUFFER, 0);
			glBindVertexArray(0);
		}
		// render Cube
		glBindVertexArray(cubeVAO);
		glDrawArrays(GL_TRIANGLES, 0, 36);
		glBindVertexArray(0);

		//glDepthMask(GL_TRUE);
		glEnable(GL_CULL_FACE);
		glCullFace(GL_BACK);
	};
	void CubeMapEnvironment::Init(const std::string& path)
	{
		CN_PROFILE_FUNCTION()

		Cube_Shader = (Shader::Create("Crimson_Editor/Assets/Shaders/CubeMapShader.glsl"));
		equirectangularToCube_shader = Shader::Create("Crimson_Editor/Assets/Shaders/equirectangularToCube_shader.glsl");
		irradiance_shader = Shader::Create("Crimson_Editor/Assets/Shaders/irradianceCubeMapShader.glsl");
		prefilterShader = Shader::Create("Crimson_Editor/Assets/Shaders/IBL_preFilteredSpecularMap.glsl");
		BRDFSumShader = Shader::Create("Crimson_Editor/Assets/Shaders/IBL_brdfSum.glsl");

		int width = 1920, height = 1080, channels;
		float* hdr_map_data = nullptr, *resized_image=nullptr;


		stbi_set_flip_vertically_on_load(1);
		hdr_map_data = stbi_loadf(path.c_str(), &width, &height, &channels, 0);

		if (hdr_map_data) {
			glGenTextures(1, &hdrMapID);//load the hdr map on to the texture slot
			glBindTexture(GL_TEXTURE_2D, hdrMapID);
			glTexImage2D(GL_TEXTURE_2D, 0, GL_RGB16F, width, height, 0, GL_RGB, GL_FLOAT, hdr_map_data);
			glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
			glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
			glBindTextureUnit(ENV_SLOT, hdrMapID);
			glBindTexture(GL_TEXTURE_2D, 0);
			stbi_image_free(hdr_map_data);
		}
		else {
			CN_CORE_ERROR("HDR Map Failed to Load!");
			CN_CORE_ERROR("STB Failure Reason: {0}", stbi_failure_reason());
		}

		EditorCamera camera;//Set up camera
		camera.SetPerspctive(90.0f, 0.1f, 10.f);
		camera.SetViewportSize(1.0f);
		camera.SetViewportSize(1.0);
		camera.SetCameraPosition({ 0,0,0 });
		
		//make frame buffer
		glGenFramebuffers(1, &framebuffer_id);
		glBindFramebuffer(GL_FRAMEBUFFER, framebuffer_id);

		//make cube map texture
		glGenTextures(1, &tex_id);
		glBindTexture(GL_TEXTURE_CUBE_MAP, tex_id);
		for (int i = 0; i < 6; i++) {
			glTexImage2D(GL_TEXTURE_CUBE_MAP_POSITIVE_X + i, 0, GL_RGB16F, captureRes, captureRes, 0, GL_RGB, GL_FLOAT, nullptr);
		}
		glTexParameteri(GL_TEXTURE_CUBE_MAP, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
		glTexParameteri(GL_TEXTURE_CUBE_MAP, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
		glTexParameteri(GL_TEXTURE_CUBE_MAP, GL_TEXTURE_WRAP_R, GL_CLAMP_TO_EDGE);
		glTexParameteri(GL_TEXTURE_CUBE_MAP, GL_TEXTURE_MIN_FILTER, GL_LINEAR_MIPMAP_LINEAR);
		glTexParameteri(GL_TEXTURE_CUBE_MAP, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
		
		glGenRenderbuffers(1, &renderBuffer_id);
		glBindRenderbuffer(GL_RENDERBUFFER, renderBuffer_id);
		glRenderbufferStorage(GL_RENDERBUFFER, GL_DEPTH_COMPONENT24, captureRes, captureRes);
		glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT, GL_RENDERBUFFER, renderBuffer_id);

		GLenum draw_buffers[] = { GL_COLOR_ATTACHMENT0 };
		glDrawBuffers(1, draw_buffers);

		equirectangularToCube_shader->Bind();
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

		glBindFramebuffer(GL_FRAMEBUFFER, framebuffer_id);
		glViewport(0, 0, captureRes, captureRes);
		for (int i = 0; i < 6; i++)
		{
			glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_CUBE_MAP_POSITIVE_X + i, tex_id, 0);
			if (glCheckFramebufferStatus(GL_FRAMEBUFFER) == GL_FRAMEBUFFER_COMPLETE)
				CN_CORE_TRACE("FrameBuffer {0}, for Equirectangular Cube Shader Complete", i+1);
			glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);//clear the buffers each time

			equirectangularToCube_shader->SetMat4("u_ProjectionView", camera.GetProjectionMatrix()*captureViews[i]);
			RenderUnitCube();			
		}
		glBindFramebuffer(GL_FRAMEBUFFER, 0);
		glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);//clear the buffers each time
		glViewport(0, 0, 1920, 1080);

		glBindTexture(GL_TEXTURE_CUBE_MAP, tex_id);
		glGenerateMipmap(GL_TEXTURE_CUBE_MAP);


		glBindTexture(GL_TEXTURE_CUBE_MAP, tex_id);
		glBindTextureUnit(ENV_SLOT, tex_id);//bind the cube-map to ENV-SLOT
		glBindTexture(GL_TEXTURE_CUBE_MAP, 0);

		ConstructIrradianceMap(camera.GetProjectionMatrix());
		CreateSpecularMap(camera.GetProjectionMatrix(), &captureViews[0]);
	}

	void CubeMapEnvironment::RenderCubeMap( const glm::mat4& view, const glm::mat4& proj, const glm::vec3& view_dir)
	{

		CN_PROFILE_FUNCTION()

		Cube_Shader->Bind();
		Cube_Shader->SetInt("env", IRR_ENV_SLOT);

		RenderQuad(view, proj);
	}
	void CubeMapEnvironment::ConstructIrradianceMap(const glm::mat4& proj)
	{		

		CN_PROFILE_FUNCTION()

		const int irrMapWidth = 32;
		
		glGenTextures(1, &irradiance_map_id);
		glBindTexture(GL_TEXTURE_CUBE_MAP, irradiance_map_id);
		for (int i = 0; i < 6; i++)//iterate over 6 images each representing the side of a cube
		{
			glTexImage2D(GL_TEXTURE_CUBE_MAP_POSITIVE_X + i, 0, GL_RGB16F, irrMapWidth, irrMapWidth, 0, GL_RGB, GL_FLOAT, nullptr);
		}
		glTexParameteri(GL_TEXTURE_CUBE_MAP, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
		glTexParameteri(GL_TEXTURE_CUBE_MAP, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
		glTexParameteri(GL_TEXTURE_CUBE_MAP, GL_TEXTURE_WRAP_R, GL_CLAMP_TO_EDGE);
		glTexParameteri(GL_TEXTURE_CUBE_MAP, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
		glTexParameteri(GL_TEXTURE_CUBE_MAP, GL_TEXTURE_MAG_FILTER, GL_LINEAR);


		glBindFramebuffer(GL_FRAMEBUFFER, framebuffer_id);
		glBindRenderbuffer(GL_RENDERBUFFER, renderBuffer_id);
		glRenderbufferStorage(GL_RENDERBUFFER, GL_DEPTH_COMPONENT24, irrMapWidth, irrMapWidth);//resize the render-buffer

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
		irradiance_shader->SetInt("environmentMap", ENV_SLOT);

		glBindFramebuffer(GL_FRAMEBUFFER, framebuffer_id);
		glViewport(0, 0, irrMapWidth, irrMapWidth);
		for (int i = 0; i < 6; i++)
		{
			glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_CUBE_MAP_POSITIVE_X + i, irradiance_map_id, 0);
			if (glCheckFramebufferStatus(GL_FRAMEBUFFER) == GL_FRAMEBUFFER_COMPLETE)
				CN_CORE_TRACE("FrameBuffer {0} Complete for Irradiance map", i+1);
			glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);//clear the buffers each time

			irradiance_shader->SetMat4("u_ProjectionView", proj * captureViews[i]);
			RenderUnitCube();
		}
		glBindFramebuffer(GL_FRAMEBUFFER, 0);
		glBindTextureUnit(IRR_ENV_SLOT, irradiance_map_id);
	}
	void CubeMapEnvironment::SwitchToFace(int n, float& pitch, float& yaw)
	{
		switch (n)
		{
			//pitch , yaw
		case 0:
			pitch = 0.f;
			yaw = -90.f;
			break;
		case 1:
			pitch = 0.f;
			yaw = 90.f;
			break;
		case 2:
			pitch = 90.0f;
			yaw = 180.f;
			break;
		case 3:
			pitch = -90.f;
			yaw = 180.f;
			break;
		case 4:
			pitch = 0.f;
			yaw = 0;
			break;
		case 5:
			pitch = 0.f;
			yaw = 180.f;
			break;
		}
	}


	void CubeMapEnvironment::CreateSpecularMap(const glm::mat4& proj, glm::mat4* viewDirs)
	{


		CN_PROFILE_FUNCTION()

		// pbr: run a quasi monte-carlo simulation on the environment lighting to create a prefilter (cube)map.
		// ----------------------------------------------------------------------------------------------------
		unsigned int prefilterMap; //will be used in specular reflections
		glGenTextures(1, &prefilterMap);
		glBindTexture(GL_TEXTURE_CUBE_MAP, prefilterMap);
		for (unsigned int i = 0; i < 6; ++i)
		{
			glTexImage2D(GL_TEXTURE_CUBE_MAP_POSITIVE_X + i, 0, GL_RGB16F, 128, 128, 0, GL_RGB, GL_FLOAT, nullptr);
		}
		glGenerateMipmap(GL_TEXTURE_CUBE_MAP);
		glTexParameteri(GL_TEXTURE_CUBE_MAP, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
		glTexParameteri(GL_TEXTURE_CUBE_MAP, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
		glTexParameteri(GL_TEXTURE_CUBE_MAP, GL_TEXTURE_WRAP_R, GL_CLAMP_TO_EDGE);
		glTexParameteri(GL_TEXTURE_CUBE_MAP, GL_TEXTURE_MIN_FILTER, GL_LINEAR_MIPMAP_LINEAR);
		glTexParameteri(GL_TEXTURE_CUBE_MAP, GL_TEXTURE_MAG_FILTER, GL_LINEAR);

		prefilterShader->Bind();
		prefilterShader->SetInt("environmentMap", ENV_SLOT);

		glBindFramebuffer(GL_FRAMEBUFFER, framebuffer_id);
		unsigned int maxMipLevels = 5;
		for (unsigned int mip = 0; mip < maxMipLevels; ++mip)
		{
			// reisze framebuffer according to mip-level size.
			unsigned int mipWidth = static_cast<unsigned int>(128 * std::pow(0.5, mip));
			unsigned int mipHeight = static_cast<unsigned int>(128 * std::pow(0.5, mip));
			glBindRenderbuffer(GL_RENDERBUFFER, renderBuffer_id);
			glRenderbufferStorage(GL_RENDERBUFFER, GL_DEPTH_COMPONENT24, mipWidth, mipHeight);
			glViewport(0, 0, mipWidth, mipHeight);

			float roughness = (float)mip / (float)(maxMipLevels - 1);
			prefilterShader->SetFloat("roughness", roughness);
			for (unsigned int i = 0; i < 6; ++i)
			{
				glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_CUBE_MAP_POSITIVE_X + i, prefilterMap, mip);
				glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
				prefilterShader->SetMat4("u_ProjectionView", proj * viewDirs[i]);
				RenderUnitCube();
			}
		}
		glBindFramebuffer(GL_FRAMEBUFFER, 0);
		glBindTextureUnit(ENV_SLOT, prefilterMap); //specular map

		 // pbr: generate a 2D LUT from the BRDF equations used.
		// ----------------------------------------------------
		unsigned int brdfLUTTexture;
		glGenTextures(1, &brdfLUTTexture);
		glBindTexture(GL_TEXTURE_2D, brdfLUTTexture);
		glTexImage2D(GL_TEXTURE_2D, 0, GL_RG16F, captureRes, captureRes, 0, GL_RG, GL_FLOAT, 0);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);

		glBindFramebuffer(GL_FRAMEBUFFER, framebuffer_id);
		glBindRenderbuffer(GL_RENDERBUFFER, renderBuffer_id);
		glRenderbufferStorage(GL_RENDERBUFFER, GL_DEPTH_COMPONENT24, captureRes, captureRes);
		glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, brdfLUTTexture, 0);

		BRDFSumShader->Bind();
		glViewport(0, 0, captureRes, captureRes);
		glClear(GL_COLOR_BUFFER_BIT| GL_DEPTH_BUFFER_BIT);
		RenderQuad();
		glBindFramebuffer(GL_FRAMEBUFFER, 0);

		glBindTextureUnit(LUT_SLOT, brdfLUTTexture);
	}

	void CubeMapEnvironment::RenderQuad()
	{


		CN_PROFILE_FUNCTION()

		//this function renders a quad infront of the camera
		glDisable(GL_CULL_FACE);
		glDepthMask(GL_FALSE);

		//auto inv = glm::inverse(proj * glm::mat4(glm::mat3(view)));//get inverse of projection view to convert cannonical view to world space
		glm::vec4 data[] = {
		glm::vec4(-1,-1,0,1),glm::vec4(0,0,0,0),
		glm::vec4(1,-1,0,1),glm::vec4(1,0,0,0),
		glm::vec4(1,1,0,1),glm::vec4(1,1,0,0),
		glm::vec4(-1,1,0,1),glm::vec4(0,1,0,0)
		};

		Ref<VertexArray> vao = VertexArray::Create();
		Ref<VertexBuffer> vb = VertexBuffer::Create(&data[0].x, sizeof(data));
		unsigned int i_data[] = { 0,1,2,0,2,3 };
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

	void CubeMapEnvironment::RenderQuad(const glm::mat4& view, const glm::mat4& proj)
	{


		CN_PROFILE_FUNCTION()

		glDisable(GL_CULL_FACE);
		glDepthMask(GL_FALSE);

		glm::mat4 inv = glm::inverse(glm::mat4(glm::mat3(view))) * glm::inverse(proj);

		glm::vec4 data[] = 
		{
		glm::vec4(-1,-1,0,1),inv * glm::vec4(-1,-1,0,1),
		glm::vec4(1,-1,0,1),inv * glm::vec4(1,-1,0,1),
		glm::vec4(1,1,0,1),	inv * glm::vec4(1,1,0,1),
		glm::vec4(-1,1,0,1),inv * glm::vec4(-1,1,0,1),
		};

		Ref<VertexArray> vao = VertexArray::Create();
		Ref<VertexBuffer> vb = VertexBuffer::Create(&data[0].x, sizeof(data));

		std::array<uint32_t, 6> i_data = { 0,1,2,0,2,3 };
		Ref<IndexBuffer> ib = IndexBuffer::Create(&i_data[0], sizeof(uint32_t) * i_data.size());

		Ref<BufferLayout> bl = std::make_shared<BufferLayout>();

		bl->push("position", ShaderDataType::Float4);
		bl->push("direction", ShaderDataType::Float4);

		vao->AddBuffer(bl, vb);
		vao->SetIndexBuffer(ib);

		RenderCommand::DrawIndex(*vao, GL_TRIANGLES);

		glDepthMask(GL_TRUE);
		glEnable(GL_CULL_FACE);
		glCullFace(GL_BACK);
	}
}