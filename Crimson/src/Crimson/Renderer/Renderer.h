#pragma once

#include "RenderCommand.h"
#include "OrthographicCamera.h"
#include "glm/glm.hpp"
#include "Shader.h"
#include "RendererAPI.h"

namespace Crimson {

	class Renderer {
	public:
		~Renderer() { delete m_data; }
		static void Init();
		static void WindowResize(uint32_t Width, uint32_t Height);
		static void BeginScene(OrthographicCamera& camera);
		static void Submit(Shader& shader, VertexArray& vertexarray, glm::mat4 ModelTransform = glm::mat4(1));
		static void EndScene() {}

		struct data {
			glm::mat4 m_ProjectionViewMatrix;
		};
		static data* m_data;
	};
}