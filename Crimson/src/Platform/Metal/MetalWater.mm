#include "cnpch.h"

#include "MetalWater.h"
#include "glad/glad.h"
#include "Crimson/Renderer/RenderCommand.h"

namespace Crimson {

	MetalWater::MetalWater(const glm::vec3& dims, const glm::vec4& water_color, const glm::vec2& screen_size)
	{
		CN_PROFILE_FUNCTION()

		m_waterShader = Shader::Create("Crimson_Editor/Assets/Shaders/GLSL/Water.glsl");

		m_Fbo1 = FrameBuffer::Create({ 512, 512 });
		m_Fbo2 = FrameBuffer::Create({ 512, 512 });
		

		// water quad

		std::array<glm::vec4, 8> data =
		{
			glm::vec4(0, 0, 0, 1),               // 0 - Bottom-left-back (origin)
			glm::vec4(dims.x, 0, 0, 1),          // 1 - Bottom-right-back
			glm::vec4(dims.x, dims.y, 0, 1),     // 2 - Top-right-back
			glm::vec4(0, dims.y, 0, 1),          // 3 - Top-left-back
			glm::vec4(0, 0, dims.z, 1),          // 4 - Bottom-left-front
			glm::vec4(dims.x, 0, dims.z, 1),     // 5 - Bottom-right-front
			glm::vec4(dims.x, dims.y, dims.z, 1),// 6 - Top-right-front
			glm::vec4(0, dims.y, dims.z, 1)      // 7 - Top-left-front
		};

		std::array<uint32_t, 36> i_data = {
			// Front face
			0, 1, 2, 2, 3, 0,
			// Right face
			1, 5, 6, 6, 2, 1,
			// Back face
			5, 4, 7, 7, 6, 5,
			// Left face
			4, 0, 3, 3, 7, 4,
			// Top face
			3, 2, 6, 6, 7, 3,
			// Bottom face
			4, 5, 1, 1, 0, 4
		};

		m_VAO = VertexArray::Create();
		m_VBO = VertexBuffer::Create(&data[0].x, sizeof(data));
		m_EBO = IndexBuffer::Create(&i_data[0], sizeof(i_data));
		m_Bl = std::make_shared<BufferLayout>(); //buffer layout

		m_Bl->push("position", ShaderDataType::Float4);
		m_VAO->AddBuffer(m_Bl, m_VBO);
		m_VAO->SetIndexBuffer(m_EBO);

	}

	void MetalWater::SetWaterParameters(const glm::vec3& dims, const glm::vec4& water_color)
	{

	}

	void MetalWater::RenderWater(Camera& cam, const glm::vec2& screen_size)
	{
		m_waterShader->Bind();
		m_waterShader->SetMat4("u_ProjectionView", cam.GetProjectionView());
		m_waterShader->SetFloat4("u_Color",  m_waterColor);
		RenderCommand::DrawIndex(*m_VAO, GL_TRIANGLES);
	}

}