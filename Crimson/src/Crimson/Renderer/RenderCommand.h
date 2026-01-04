#pragma once

#include "RendererAPI.h"

#include <glm/glm.hpp>

namespace Crimson {

	class RenderCommand {
	public:
		inline static void Init(){
			s_RendererAPI->Init(); 
		}
		inline static void SetViewport(uint32_t Width, uint32_t Height){
			s_RendererAPI->SetViewPort(Width, Height);
		}
		inline static void ClearColor(const glm::vec4& color) {
			s_RendererAPI->ClearColor(color);
		}
		inline static void Clear() {
			s_RendererAPI->Clear();
		}
		inline static void Draw(VertexArray& vertexarray, uint32_t renderingMode = 0, size_t count = 0, int first = 0){
			if (vertexarray.GetIndexBuffer()) {
				s_RendererAPI->DrawIndex(vertexarray, renderingMode);
			}
			else {
				s_RendererAPI->DrawArrays(vertexarray, count, renderingMode, first);
			}
		}
		inline static void DrawIndex(VertexArray& vertexarray, uint32_t renderingMode) {
			s_RendererAPI->DrawIndex(vertexarray, renderingMode);
		}
		inline static void DrawArrays(VertexArray& vertexarray, size_t count, int first = 0){
			s_RendererAPI->DrawArrays(vertexarray, count, first);
		}
		inline static void DrawArrays(VertexArray& vertexarray, size_t count, uint32_t renderingMode, int first = 0){
			s_RendererAPI->DrawArrays(vertexarray, count, renderingMode, first);
		}
		inline static void DrawInstancedArrays(VertexArray& vertexarray, size_t count, size_t instance_count, int first = 0){
			s_RendererAPI->DrawInstancedArrays(vertexarray, count, instance_count, first);
		}

		//indirectBufferID is bound to GL_DRAW_INDIRECT_BUFFER before the glDrawIndirect draw call to pass information to the gpu
		//this is used when the number of instances to draw is unknown in the cpu side but gpu produces the num instances to draw
		//so without copying the data from the gpu->cpu directly use gpu data to draw. 
		inline static void DrawArraysIndirect(VertexArray& vertexarray, uint32_t indirectBufferID) {
			s_RendererAPI->DrawArraysIndirect(vertexarray, indirectBufferID);
		}
		inline static void DrawElementsIndirect(VertexArray& vertexarray, DrawElementsIndirectCommand& indirectCommand){
			s_RendererAPI->DrawElementsIndirect(vertexarray, indirectCommand);
		}
		inline static void DrawElementsIndirect(VertexArray& vertexarray, uint32_t indirectBufferID){
                s_RendererAPI->DrawElementsIndirect(vertexarray, indirectBufferID);
        }
		inline static void DrawLine(VertexArray& vertexarray, uint32_t& count){
			s_RendererAPI->DrawLine(vertexarray, count);
		}
		inline static glm::vec2 GetViewportSize(){
			return s_RendererAPI->GetViewportSize();
		}
		inline static void SetDepthTest(bool val) {
			s_RendererAPI->SetDepthTest(val);
		}
		inline static void SetCullFace(bool val) {
			s_RendererAPI->SetCullFace(val);
		}
	private:
		static Ref<RendererAPI> GetRendererAPI();
		static Scope<RendererAPI> s_RendererAPI;
	};

}
