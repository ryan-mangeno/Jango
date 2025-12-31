#include "cnpch.h"
#include "OpenGLVertexArray.h"
#include "glad/glad.h"

namespace Crimson {

	static uint32_t GetSize(ShaderDataType type)
	{
		switch (type) 
		{

			case ShaderDataType::Float:  return 1;
			case ShaderDataType::Float2: return 2;
			case ShaderDataType::Float3: return 3;
			case ShaderDataType::Float4: return 4;
			case ShaderDataType::Int:    return 1;
			case ShaderDataType::Int2:   return 2;
			case ShaderDataType::Int3:   return 3;
			case ShaderDataType::Int4:   return 4;
			case ShaderDataType::Mat2:   return 2 * 2;
			case ShaderDataType::Mat3:   return 3 * 3;
			case ShaderDataType::Mat4:   return 4 * 4;

			default:                     CN_CORE_ERROR("Unidentfied Type")

		}
	}

	static GLenum GetType(ShaderDataType type) 
	{
		switch (type) 
			{
			case ShaderDataType::Float:  return GL_FLOAT;
			case ShaderDataType::Float2: return GL_FLOAT;
			case ShaderDataType::Float3: return GL_FLOAT;
			case ShaderDataType::Float4: return GL_FLOAT;
			case ShaderDataType::Int:    return GL_INT;
			case ShaderDataType::Int2:   return GL_INT;
			case ShaderDataType::Int3:   return GL_INT;
			case ShaderDataType::Int4:   return GL_INT;
			case ShaderDataType::Mat2:   return GL_FLOAT;
			case ShaderDataType::Mat3:   return GL_FLOAT;
			case ShaderDataType::Mat4:   return GL_FLOAT;

			default:                     CN_CORE_ERROR("Unidentfied Type")
		}
	}
	OpenGLVertexArray::OpenGLVertexArray()
	{
		glGenVertexArrays(1, &m_RendererID);
		glBindVertexArray(m_RendererID);
	}
	OpenGLVertexArray::~OpenGLVertexArray()
	{
		glDeleteVertexArrays(1, &m_RendererID);
	}
	void OpenGLVertexArray::Bind() const
	{
		glBindVertexArray(m_RendererID);
	}
	void OpenGLVertexArray::UnBind() const
	{
		glBindVertexArray(0);
	}
	void OpenGLVertexArray::AddBuffer(Ref<BufferLayout>& layout, Ref<VertexBuffer>& vertexBuffer)
	{

		vertexBuffer->Bind();
		glBindVertexArray(m_RendererID);
			
		std::vector<Crimson::BufferElements*>& elements = layout->GetElements();
		uint64_t offset = 0;

		for (size_t i = 0; i < elements.size(); i++)
		{
			glEnableVertexAttribArray(i);
			glVertexAttribPointer(
				i, 
				GetSize(elements[i]->Type), 
				GetType(elements[i]->Type), 
				elements[i]->Normalized ? GL_TRUE : GL_FALSE, 
				layout->GetStride(), 
				(const void*)offset
			);

			offset += GetSize(elements[i]->Type) * sizeof(GetType(elements[i]->Type));
		}

		m_VertexBuffer.push_back(vertexBuffer);
	}
	void OpenGLVertexArray::SetIndexBuffer(Ref<IndexBuffer> IndexBuffer)
	{
		glBindVertexArray(m_RendererID);
		IndexBuffer->Bind();
		m_IndexBuffer = IndexBuffer;
	}
}
