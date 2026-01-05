#include "cnpch.h"
#include "MetalCubeMapReflection.h"
#include "glad/glad.h"
#include "stb_image.h"
#include "stb_image_resize.h"
#include "Crimson/Scene/Scene.h"

namespace Crimson {

	MetalCubeMapReflection::MetalCubeMapReflection()
		:cubemap_width(2048.0f),cubemap_height(2048.0f)
	{
		RenderCommand::Init();
		shader = Shader::Create("Crimson_Editor/Assets/Shaders/{API}/CubeMapReflection{EXT}");//texture shader
		CreateCubeMapTexture();
	}

	MetalCubeMapReflection::~MetalCubeMapReflection()
	{
	}

	void MetalCubeMapReflection::CreateCubeMapTexture()
	{

		CN_PROFILE_FUNCTION()

		float* data = nullptr;
		int width = -1, height = -1, channels = -1;

		glGenTextures(1, &tex_id);
		glBindTexture(GL_TEXTURE_CUBE_MAP, tex_id);

		glGenRenderbuffers(1, &depth_id);
		glBindRenderbuffer(GL_RENDERBUFFER, depth_id);
		glRenderbufferStorage(GL_RENDERBUFFER, GL_DEPTH_COMPONENT, cubemap_width, cubemap_height);

		std::string filename = "Assets/Textures/Outdoor-Cube-map/";

		for (int i = 0; i < 6; i++)//iterate over 6 images each representing the side of a cube
		{
			stbi_set_flip_vertically_on_load_thread(1);
			data = stbi_loadf((filename + "irr_" + std::to_string(i) + ".jpg").c_str(), &width, &height, &channels, 0);
			if (!data)
			{
				CN_CORE_ERROR("Irradiance map not loaded")
			}
			else
			{
				glTexImage2D(GL_TEXTURE_CUBE_MAP_POSITIVE_X + i, 0, GL_RGB16F, width, height, 0, GL_RGB, GL_FLOAT, data);
			}
		}

		glGenerateMipmap(GL_TEXTURE_CUBE_MAP);
		glTexParameteri(GL_TEXTURE_CUBE_MAP, GL_TEXTURE_MIN_FILTER, GL_LINEAR_MIPMAP_LINEAR);
		glTexParameteri(GL_TEXTURE_CUBE_MAP, GL_TEXTURE_MAG_FILTER, GL_LINEAR_MIPMAP_LINEAR);
		glTexParameteri(GL_TEXTURE_CUBE_MAP, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
		glTexParameteri(GL_TEXTURE_CUBE_MAP, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
		glTexParameteri(GL_TEXTURE_CUBE_MAP, GL_TEXTURE_WRAP_R, GL_CLAMP_TO_EDGE);

		glBindTexture(GL_TEXTURE_CUBE_MAP, tex_id);

	}

	void MetalCubeMapReflection::RenderToCubeMap(Scene& scene)
	{

		CN_PROFILE_FUNCTION()
		
		shader->Bind();
		glm::vec2 size = RenderCommand::GetViewportSize();
		
		EditorCamera cam = EditorCamera();
		cam.SetPerspctive(90.00f, -10.0f, 1000.0f);
		cam.SetUPVector({ 0.f, 1.f ,0.f });
		cam.SetCameraPosition({ 0.f ,-5.f ,0.f });
		
		glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
		glBindFramebuffer(GL_DRAW_FRAMEBUFFER, framebuffer_id);
		glViewport(0, 0, cubemap_width , cubemap_height);
		glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);


		shader->SetFloat3("LightPosition", { 2.f, 3.f, 6.f }); //world position
		shader->SetInt("env", GL_TEXTURE_CUBE_MAP);
		for (int i = 0; i < 6; i++)
		{
			glFramebufferTexture2D(GL_DRAW_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_CUBE_MAP_POSITIVE_X + i, tex_id, 0);//Render the scene in the corresponding face on the cube map and "GL_COLOR_ATTACHMENT0" Represents the Render target where the fragment shader should output the color
			if (glCheckFramebufferStatus(GL_FRAMEBUFFER) != GL_FRAMEBUFFER_COMPLETE)
				CN_CORE_TRACE("FrameBuffer Creation Failed");

			glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);//clear the buffers each time

			SwitchToFace(i);//rotate the camera
			cam.RotateCamera(yaw, pitch);

			//Render the cube map
			shader->Bind();
			CubeMapEnvironment::RenderQuad(cam.GetViewMatrix(), cam.GetProjectionMatrix()); //cubemap shader is binded here follow this order

			shader->Bind();//bind the shader and pass the projectionview and Eye pos as uniform.
			shader->SetMat4("u_ProjectionView", cam.GetProjectionView());
			shader->SetFloat3("EyePosition", cam.GetCameraPosition());

			
			scene.getRegistry().each([&](auto m_entity)//iterate through every entities and render them
				{
					Entity Entity(&scene, m_entity);
					const glm::mat4& transform = Entity.GetComponent<TransformComponent>().GetTransform();

					if (cam.bIsMainCamera) 
					{
						if (Entity.HasComponent<SpriteRenderer>()) 
						{
							auto& SpriteRendererComponent = Entity.GetComponent<SpriteRenderer>();
							Renderer3D::DrawMesh(*Scene::Cube, transform, SpriteRendererComponent.Color);
						}
						else
						{
							Renderer3D::DrawMesh(*Scene::Cube, transform, Entity.m_DefaultColor);
						}

					}
				});
			
		}
	
	}

	void MetalCubeMapReflection::Bind(uint32_t slot)
	{
		glBindTextureUnit(slot, tex_id);
	}

	void MetalCubeMapReflection::UnBind()
	{
		glBindTexture(GL_TEXTURE_CUBE_MAP, 0);
	}

	unsigned int MetalCubeMapReflection::GetTexture_ID()
	{
		return tex_id;
	}

	void MetalCubeMapReflection::SetCubeMapResolution(float width, float height)
	{
		cubemap_width = width;
		cubemap_height = height;
	}
	void  MetalCubeMapReflection::SwitchToFace(int n)
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
			yaw = 0.f;
			break;
		case 5:
			pitch = 0.f;
			yaw = 180.f;
			break;
		}
	}
}