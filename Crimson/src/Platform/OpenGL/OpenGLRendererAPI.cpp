#include "cnpch.h"
#include "OpenGLRendererAPI.h"
#include "glad/glad.h"

namespace Crimson {

	OpenGLRendererAPI::OpenGLRendererAPI()
	{
	}

	OpenGLRendererAPI::~OpenGLRendererAPI()
	{
	}

	void OpenGLRendererAPI::ClearColor(const glm::vec4& color)
	{
		glClearColor(color.r, color.g, color.b, color.a);
	}

	void OpenGLRendererAPI::Clear()
	{
		glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT | GL_STENCIL_BUFFER_BIT);
	}

	void OpenGLRendererAPI::DrawIndex(VertexArray& vertexarray, uint32_t renderingMode)
	{

		renderingMode == GL_LINE ? glPolygonMode(GL_FRONT_AND_BACK, GL_LINE) : glPolygonMode(GL_FRONT_AND_BACK, GL_FILL);


		vertexarray.Bind();
		glDrawElements(GL_TRIANGLES, vertexarray.GetIndexBuffer()->GetCount(), GL_UNSIGNED_INT, (const void*)0);
	}

	void OpenGLRendererAPI::DrawArrays(VertexArray& vertexarray, size_t count, int first)
	{
		vertexarray.Bind();
		glDrawArrays(GL_TRIANGLES, first, count);
	}

	void OpenGLRendererAPI::DrawArrays(VertexArray& vertexarray, size_t count, uint32_t renderingMode, int first)
	{
		renderingMode == GL_LINE ? glPolygonMode( GL_FRONT_AND_BACK, GL_LINE ) : glPolygonMode( GL_FRONT_AND_BACK, GL_FILL);


		// remove, the check for draw elements or arrays, need to defer calls with index buffers to draw index
		vertexarray.Bind();
		if (vertexarray.GetIndexBuffer())
		{
			vertexarray.GetIndexBuffer()->Bind();
			glDrawElements(GL_TRIANGLES, vertexarray.GetIndexBuffer()->GetCount(), GL_UNSIGNED_INT, nullptr);
		}
		else
		{
			glDrawArrays(renderingMode, first, count);
		}
	}

	void OpenGLRendererAPI::DrawInstancedArrays(VertexArray& vertexarray, size_t count, size_t instance_count, int first)
	{
		vertexarray.Bind();
		glDrawArraysInstanced(GL_TRIANGLES, first, count, instance_count);
	}

	void OpenGLRendererAPI::DrawArraysIndirect(VertexArray& vertexarray, uint32_t indirectBufferID)
	{
		glBindBuffer(GL_DRAW_INDIRECT_BUFFER, indirectBufferID);
		vertexarray.Bind();
		glDrawArraysIndirect(GL_TRIANGLES, 0);
	}

	void OpenGLRendererAPI::DrawElementsIndirect(VertexArray& vertexarray, uint32_t indirectBufferID)
	{
		glBindBuffer(GL_DRAW_INDIRECT_BUFFER, indirectBufferID);
		vertexarray.Bind();
		vertexarray.GetIndexBuffer()->Bind();
		glDrawElementsIndirect(GL_TRIANGLES, GL_UNSIGNED_INT, 0);
	}
	
	void OpenGLRendererAPI::DrawElementsIndirect(VertexArray& vertexarray, DrawElementsIndirectCommand& indirectCommand)
	{
		vertexarray.Bind();
		vertexarray.GetIndexBuffer()->Bind();
		/*
		If a buffer is bound to the GL_DRAW_INDIRECT_BUFFER binding at the time of a call to glDrawElementsIndirect, 
		indirect is interpreted as an offset, in basic machine units, into that buffer and the parameter data is read from the buffer rather than from client memory.
		*/
		glDrawElementsIndirect(GL_TRIANGLES, GL_UNSIGNED_INT, (void*)&indirectCommand);
	}
	

	void OpenGLRendererAPI::DrawLine(VertexArray& vertexarray, uint32_t count)
	{
		vertexarray.Bind();
		glDrawArrays(GL_LINES, 0, count);
	}
	void OpenGLRendererAPI::Init()
	{
		int MaxTextureImageUnits;
		glGetIntegerv(GL_MAX_COMBINED_TEXTURE_IMAGE_UNITS, &MaxTextureImageUnits);
		CN_CORE_INFO("Number of texture slots available are :- {}", MaxTextureImageUnits);

		//glEnable(GL_DEBUG_OUTPUT);
		//glEnable(GL_DEBUG_OUTPUT_SYNCHRONOUS);
		//glDebugMessageCallback(glDebugOutput, nullptr);
		//glEnable(GL_MULTISAMPLE);
		//glEnable(GL_SAMPLE_ALPHA_TO_COVERAGE_ARB);
		glEnable(GL_BLEND);
		glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
		glEnable(GL_DEPTH_TEST);
		glDepthFunc(GL_LESS);
		//glEnable(GL_STENCIL_TEST);
		glEnable(GL_LINE_SMOOTH);
		glEnable(GL_CULL_FACE);
		glCullFace(GL_BACK);
		glEnable(GL_TEXTURE_CUBE_MAP_SEAMLESS);
	}
	void OpenGLRendererAPI::SetViewPort(uint32_t Width, uint32_t Height)
	{
		glViewport(0, 0, Width, Height);
	}
	glm::vec2 OpenGLRendererAPI::GetViewportSize()
	{
		static float arr[4];
		glGetFloatv(GL_VIEWPORT, arr);
		return { arr[2],arr[3] };//the index 2 and 3 gives the width and height of the viewport
	}

	void OpenGLRendererAPI::SetDepthTest(bool val) {
		if (val) {
			glDepthMask(GL_TRUE);
		} else {
			glDepthMask(GL_FALSE);
		}
	}
	
	void OpenGLRendererAPI::SetCullFace(bool val) {
		if (val) {
			glEnable(GL_CULL_FACE);
			glCullFace(GL_BACK);
		} else {
			glDisable(GL_CULL_FACE);
		}
	} 


}
