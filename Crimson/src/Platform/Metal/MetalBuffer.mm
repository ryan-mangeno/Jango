#include "cnpch.h"

#include "MetalBuffer.h"
#include "Crimson/Renderer/Renderer2D.h"
#include <glad/glad.h>

namespace Crimson {

	// 	// --------------------------------------------------------------------
	// 	//							Vertex Buffer
	// 	// --------------------------------------------------------------------

	MetalVertexBuffer::MetalVertexBuffer(const float* data, uint32_t size)
	{
		glGenBuffers(1, &m_RendererID);//set up vertex buffer
		glBindBuffer(GL_ARRAY_BUFFER, m_RendererID);
		glBufferData(GL_ARRAY_BUFFER, size, data, GL_STATIC_DRAW);
	}

	MetalVertexBuffer::MetalVertexBuffer(uint32_t size, BufferStorageType Storage_Type)
	{
		glCreateBuffers(1, &m_RendererID);
		glBindBuffer(GL_ARRAY_BUFFER, m_RendererID);

		constexpr GLbitfield flags = 
			  GL_MAP_WRITE_BIT 
			| GL_MAP_PERSISTENT_BIT
			| GL_MAP_COHERENT_BIT;

		switch (Storage_Type)
		{
		case BufferStorageType::MUTABLE:
			glBufferData(GL_ARRAY_BUFFER, size, nullptr, GL_DYNAMIC_DRAW);
			break;
		case BufferStorageType::IMMUTABLE:
			glBufferStorage(GL_ARRAY_BUFFER, size, nullptr, flags);
			break;
		default:
			CN_CORE_ERROR("Select correct storage type");
			glBufferData(GL_ARRAY_BUFFER, size, nullptr, GL_DYNAMIC_DRAW);
			break;
		}
	}

	MetalVertexBuffer::~MetalVertexBuffer()
	{
		glDeleteBuffers(1, &m_RendererID);
	}

	void MetalVertexBuffer::Bind() const
	{
		glBindBuffer(GL_ARRAY_BUFFER, m_RendererID);
	}

	void MetalVertexBuffer::UnBind() const
	{
		glBindBuffer(GL_ARRAY_BUFFER, 0);
	}

	void MetalVertexBuffer::SetData(uint32_t size, const void* data)
	{
		glBindBuffer(GL_ARRAY_BUFFER, m_RendererID);
		glBufferSubData(GL_ARRAY_BUFFER, 0, size, data);
	}

	void* MetalVertexBuffer::MapBuffer(uint32_t size)
	{
		auto flags = GL_MAP_WRITE_BIT | GL_MAP_PERSISTENT_BIT | GL_MAP_COHERENT_BIT;
		return glMapBufferRange(GL_ARRAY_BUFFER, 0, size, flags);
	}

	// 	// --------------------------------------------------------------------
	// 	//							Index Buffer
	// 	// --------------------------------------------------------------------


	MetalIndexBuffer::MetalIndexBuffer(const uint32_t* data, uint32_t size)
	{
		m_Elements = size / sizeof(uint32_t);
		glGenBuffers(1, &m_RendererID);
		glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, m_RendererID);
		glBufferData(GL_ELEMENT_ARRAY_BUFFER, size, data, GL_STATIC_DRAW);
	}
	MetalIndexBuffer::~MetalIndexBuffer()
	{
		glDeleteBuffers(1, &m_RendererID);
	}
	void MetalIndexBuffer::Bind() const
	{
		glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, m_RendererID);
	}
	void MetalIndexBuffer::UnBind() const
	{
		glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, 0);
	}
}