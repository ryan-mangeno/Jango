#include "cnpch.h"
#include "Atmosphere.h"

// temp
#include <glad/glad.h>

namespace Crimson {
	Ref<Shader> Atmosphere::atmosphere_shader;
	Ref<Texture2DArray> Atmosphere::skyGradients;

	void Atmosphere::RenderAtmosphere(Camera& camera,const float& atmosphere_radius)
	{

		CN_PROFILE_FUNCTION()

		skyGradients->Bind(ALBEDO_SLOT);
		atmosphere_shader->Bind();
		atmosphere_shader->SetFloat3("sun_direction", Renderer3D::m_SunLightDir);
		atmosphere_shader->SetInt("Sky_Gradient", ALBEDO_SLOT);
		atmosphere_shader->SetFloat("atmosphere_radius", 6471e3);
		atmosphere_shader->SetFloat("densityFalloff", 6);
		atmosphere_shader->SetFloat3("sun_direction", Renderer3D::m_SunLightDir);
		atmosphere_shader->SetFloat("planetRadius", 6371e3);
		atmosphere_shader->SetFloat("ScatteringStrength", 1);
		atmosphere_shader->SetFloat3("RayOrigin", glm::vec3(0, 6372e3, 0));
		atmosphere_shader->SetFloat3("view_dir", camera.GetViewDirection());
		atmosphere_shader->SetInt("u_DepthTexture", SCENE_DEPTH_SLOT); //used as a mask to render only the areas which are valid


		glm::vec3 wavelength = glm::vec3(700, 530, 440);
		glm::vec3 ScatteringCoeff = glm::vec3(0.00000519673, 0.0000121427, 0.0000296453);//glm::vec3(pow(200 / wavelength.x, 4), pow(200 / wavelength.y, 4), pow(200 / wavelength.z, 4));
		atmosphere_shader->SetFloat3("ScatteringCoeff", ScatteringCoeff * 1.f);
		RenderQuad(camera.GetViewMatrix(), camera.GetProjectionMatrix());
	}
	void Atmosphere::InitilizeAtmosphere()
	{

		CN_PROFILE_FUNCTION()
		CN_CORE_TRACE("Initializing Atmosphere");

		atmosphere_shader = Shader::Create("Crimson_Editor/Assets/Shaders/GLSL/Atmosphere.glsl");

		std::vector<std::string> gradientTex_paths = {"Assets/Textures/Sky_Gradient_Textures/SunZenith_Gradient.png",
			"Assets/Textures/Sky_Gradient_Textures/ViewZenith_Gradient.png", "Assets/Textures/Sky_Gradient_Textures/SunView_Gradient.png"};
		skyGradients = Texture2DArray::Create(gradientTex_paths);

		CN_CORE_INFO("--- Initialized Atmosphere ---");
	}
	void Atmosphere::RenderQuad(const glm::mat4& view, const glm::mat4& proj)
	{

		CN_PROFILE_FUNCTION()

		glDepthMask(GL_FALSE);//disable writing to depth buffer

		glm::mat4 inv = glm::inverse(proj * glm::mat4(glm::mat3(view)));//get inverse of projection view to convert cannonical view to world space
		glm::vec4 data[] = 
		{
			glm::vec4(-1,-1,0,1),inv * glm::vec4(-1,-1,0,1),
			glm::vec4(1,-1,0,1),inv * glm::vec4(1,-1,0,1),
			glm::vec4(1,1,0,1),	inv * glm::vec4(1,1,0,1),
			glm::vec4(-1,1,0,1),inv * glm::vec4(-1,1,0,1),
		};

		Ref<VertexArray> vao = VertexArray::Create();
		Ref<VertexBuffer> vb = VertexBuffer::Create(&data[0].x, sizeof(data));
		
		const std::array<uint32_t,6> i_data = { 0,1,2,0,2,3 };
		Ref<IndexBuffer> ib = IndexBuffer::Create(&i_data[0], sizeof(uint32_t) * i_data.size());

		Ref<BufferLayout> bl = std::make_shared<BufferLayout>(); //buffer layout

		bl->push("position", ShaderDataType::Float4);
		bl->push("direction", ShaderDataType::Float4);

		vao->AddBuffer(bl, vb);
		vao->SetIndexBuffer(ib);

		RenderCommand::DrawIndex(*vao, GL_TRIANGLES);

		glDepthMask(GL_TRUE);
	}
}