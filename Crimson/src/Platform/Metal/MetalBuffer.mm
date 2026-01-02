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
	}

	MetalVertexBuffer::MetalVertexBuffer(uint32_t size, BufferStorageType Storage_Type)
	{
	}

	MetalVertexBuffer::~MetalVertexBuffer()
	{
	}

	void MetalVertexBuffer::Bind() const
	{
	}

	void MetalVertexBuffer::UnBind() const
	{
	}

	void MetalVertexBuffer::SetData(uint32_t size, const void* data)
	{
	}

	void* MetalVertexBuffer::MapBuffer(uint32_t size)
	{
	}

	// 	// --------------------------------------------------------------------
	// 	//							Index Buffer
	// 	// --------------------------------------------------------------------


	MetalIndexBuffer::MetalIndexBuffer(const uint32_t* data, uint32_t size)
	{
	}
	MetalIndexBuffer::~MetalIndexBuffer()
	{
	}
	void MetalIndexBuffer::Bind() const
	{
	}
	void MetalIndexBuffer::UnBind() const
	{
	}
}