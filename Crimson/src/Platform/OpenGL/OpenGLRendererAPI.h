#pragma once

#include "Crimson/Renderer/RendererAPI.h"
#include <glm/glm.hpp>

namespace Crimson {

	class OpenGLRendererAPI : public RendererAPI
	{
	public:
		OpenGLRendererAPI();
		~OpenGLRendererAPI();
		void ClearColor(const glm::vec4&) override;
		void Clear() override;
		void DrawIndex(VertexArray& vertexarray, uint32_t renderingMode) override;
		void DrawArrays(VertexArray& vertexarray, size_t count, int first = 0) override;
		void DrawArrays(VertexArray& vertexarray, size_t count, uint32_t renderingMode, int first) override;
		void DrawInstancedArrays(VertexArray& vertexarray, size_t count, size_t instance_count, int first = 0) override;
		void DrawArraysIndirect(VertexArray& vertexarray, uint32_t indirectBufferID) override;
		void DrawLine(VertexArray& vertexarray, uint32_t count) override;
		
		void DrawElementsIndirect(VertexArray& vertexarray, DrawElementsIndirectCommand& indirectCommand) override;
		void DrawElementsIndirect(VertexArray& vertexarray, uint32_t indirectBufferID) override;

		void Init() override;
		void SetViewPort(uint32_t, uint32_t) override;
		virtual glm::vec2 GetViewportSize() override;
	};

}
