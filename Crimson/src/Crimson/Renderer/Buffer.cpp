#include "cnpch.h"
#include "Buffer.h"

#include "Renderer.h"
#include "RendererAPI.h"

#include "Platform/OpenGL/OpenGLBuffer.h"
#include "Platform/OpenGL/OpenGLVertexArray.h"
#include "Platform/Metal/MetalBuffer.h"
#include "Platform/Metal/MetalVertexArray.h"

#include "Crimson/Core/Core.h"

namespace Crimson {


	Ref<VertexBuffer> VertexBuffer::Create(const float* vertices, uint32_t size)
	{
		switch (RendererAPI::GetAPI())
		{
		case GraphicsAPI::None:				CN_CORE_ASSERT(false, "RendererAPI: None not supported currently!"); return nullptr;
		case GraphicsAPI::Metal:			return MakeRef<MetalVertexBuffer>(vertices, size);
		case GraphicsAPI::OpenGL:			return MakeRef<OpenGLVertexBuffer>(vertices, size);
		}

		CN_CORE_ASSERT(false, "Unknown RendererAPI!");
		return nullptr;
	}


	Ref<VertexBuffer> VertexBuffer::Create(uint32_t size, BufferStorageType type)
	{
		switch (RendererAPI::GetAPI())
		{
		case GraphicsAPI::None:				CN_CORE_ASSERT(false, "RendererAPI: None not supported currently!"); return nullptr;
		case GraphicsAPI::Metal:			return MakeRef<MetalVertexBuffer>(size, type);
		case GraphicsAPI::OpenGL:			return MakeRef<OpenGLVertexBuffer>(size, type);
		}

		CN_CORE_ASSERT(false, "Unknown RendererAPI!");
		return nullptr;
	}


	///////////////////////////////////////////////////////////////////////////


	Ref<IndexBuffer> IndexBuffer::Create(const uint32_t* indices, uint32_t size)
	{
		switch (RendererAPI::GetAPI())
		{
		case GraphicsAPI::None:			CN_CORE_ASSERT(false, "RendererAPI: None not supported currently!"); return nullptr;
		case GraphicsAPI::OpenGL:		return MakeRef<OpenGLIndexBuffer>(indices, size);
		case GraphicsAPI::Metal:		return MakeRef<MetalIndexBuffer>(indices, size);
		}

		CN_CORE_ASSERT(false, "Unknown RendererAPI!");
		return nullptr;
	}


	///////////////////////////////////////////////////////////////////////////////

	void BufferLayout::push(std::string name, ShaderDataType type)
	{
		m_Elements.push_back(new BufferElements(name, type));
		Stride += ShaderDataTypeSize(type);
	}

	/////////////////////////////////////////////////////////////////////////

	Ref<VertexArray> VertexArray::Create()
	{
		switch (RendererAPI::GetAPI()) {
		case GraphicsAPI::OpenGL:
			return MakeRef<OpenGLVertexArray>();
		case GraphicsAPI::Metal:
			return MakeRef<MetalVertexArray>();
		case GraphicsAPI::None:
			CN_CORE_ERROR("Graphics API is of type None");
			break;
		default:
			CN_CORE_ERROR("No Such Graphics Api");
		}
		return nullptr;
	}

}
