#include "cnpch.h"
#include "OpenGLVertexArray.h"
#include "glad/glad.h"

namespace Crimson {

	
	static GLenum ShaderDataTypeToOpenGLBaseType(ShaderDataType type)
    {
        switch (type)
        {
            case ShaderDataType::Float:    return GL_FLOAT;
            case ShaderDataType::Float2:   return GL_FLOAT;
            case ShaderDataType::Float3:   return GL_FLOAT;
            case ShaderDataType::Float4:   return GL_FLOAT;
            case ShaderDataType::Mat2:     return GL_FLOAT;
            case ShaderDataType::Mat3:     return GL_FLOAT;
            case ShaderDataType::Mat4:     return GL_FLOAT;
            case ShaderDataType::Int:      return GL_INT;
            case ShaderDataType::Int2:     return GL_INT;
            case ShaderDataType::Int3:     return GL_INT;
            case ShaderDataType::Int4:     return GL_INT;
            case ShaderDataType::Bool:     return GL_BOOL;
			case ShaderDataType::None:
			default:
				CN_CORE_ASSERT(false, "Unknown ShaderDataType!");

        }
        return 0;
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
			const auto& element = elements[i];
			glEnableVertexAttribArray(i);
			glVertexAttribPointer(
				i, 
				GetComponentCount(element->Type), 
				ShaderDataTypeToOpenGLBaseType(element->Type), 
				element->Normalized ? GL_TRUE : GL_FALSE, 
				layout->GetStride(), 
				(const void*)offset
			);

			offset += ShaderDataTypeSize(element->Type);
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
