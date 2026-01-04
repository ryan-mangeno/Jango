#pragma once

#include "Crimson/Renderer/RendererAPI.h"
#include <glm/glm.hpp>

namespace Crimson {

	class OpenGLRendererAPI : public RendererAPI
	{
	public:
		OpenGLRendererAPI();
		~OpenGLRendererAPI();
		virtual void ClearColor(const glm::vec4&) override;
		virtual void Clear() override;
		virtual void DrawIndex(VertexArray& vertexarray, uint32_t renderingMode) override;
		virtual void DrawArrays(VertexArray& vertexarray, size_t count, int first = 0) override;
		virtual void DrawArrays(VertexArray& vertexarray, size_t count, uint32_t renderingMode, int first) override;
		virtual void DrawInstancedArrays(VertexArray& vertexarray, size_t count, size_t instance_count, int first = 0) override;
		virtual void DrawArraysIndirect(VertexArray& vertexarray, uint32_t indirectBufferID) override;
		virtual void DrawLine(VertexArray& vertexarray, uint32_t count) override;
		
		virtual void DrawElementsIndirect(VertexArray& vertexarray, DrawElementsIndirectCommand& indirectCommand) override;
		virtual void DrawElementsIndirect(VertexArray& vertexarray, uint32_t indirectBufferID) override;

		virtual void Init() override;
		virtual void SetViewPort(uint32_t, uint32_t) override;
		virtual glm::vec2 GetViewportSize() override;

		virtual void SetDepthTest(bool val) override;
		virtual void SetCullFace(bool val) override;
	};

}
