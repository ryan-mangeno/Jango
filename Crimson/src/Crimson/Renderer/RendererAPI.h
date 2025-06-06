#pragma once

#include "Crimson/Renderer/Buffer.h"
#include "Crimson/Core/Log.h"
#include "glm/glm.hpp"

#include <crm_mth.h>

namespace Crimson {

	enum class GraphicsAPI
	{
		None = 0,
		OpenGL = 1
	};

	struct DrawElementsIndirectCommand
	{
		uint32_t Count;
		uint32_t InstanceCount;
		uint32_t FirstIndex;
		int BaseVertex;
		uint32_t BaseInstance;

		DrawElementsIndirectCommand(uint32_t count, uint32_t instanceCount, uint32_t firstIndex, int baseVertex, uint32_t baseInstance)
			: Count(count), InstanceCount(instanceCount), FirstIndex(firstIndex), BaseVertex(baseVertex), BaseInstance(baseInstance)
		{
		}
	};

	class RendererAPI {
	public:
		virtual void ClearColor(const glm::vec4&) = 0;
		virtual void Clear() = 0;
		virtual void DrawIndex(VertexArray& vertexarray, unsigned int renderingMode) = 0;
		virtual void DrawArrays(VertexArray& vertexarray, size_t count, int first = 0) = 0;
		virtual void DrawArrays(VertexArray& vertexarray, size_t count, unsigned int renderingMode, int first) = 0;
		virtual void DrawArraysIndirect(VertexArray& vertexarray, uint32_t indirectBufferID) = 0;
		virtual void DrawInstancedArrays(VertexArray& vertexarray, size_t count, size_t instance_count, int first = 0) = 0;
        virtual void DrawLine(VertexArray& vertexarray, uint32_t count) = 0;

		virtual void DrawElementsIndirect(VertexArray& vertexarray, DrawElementsIndirectCommand& indirectCommand) = 0;
		virtual void DrawElementsIndirect(VertexArray& vertexarray, uint32_t indirectBufferID) = 0;	

		inline static GraphicsAPI GetAPI() { return m_API; }
		virtual void Init() = 0;
		virtual void SetViewPort(unsigned int, unsigned int) = 0;
		virtual glm::vec2 GetViewportSize() = 0;
	private:
		static GraphicsAPI m_API;
	};
}
