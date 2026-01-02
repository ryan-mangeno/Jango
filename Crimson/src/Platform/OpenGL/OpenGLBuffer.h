#pragma once

#include "Crimson/Renderer/Buffer.h"

namespace Crimson {


	// --------------------------------------------------------------------
	//							Vertex Buffer
	// --------------------------------------------------------------------


	class OpenGLVertexBuffer :public VertexBuffer {
	public:

		OpenGLVertexBuffer(const float* data, uint32_t size);
		OpenGLVertexBuffer(uint32_t size, BufferStorageType Storage_Type = BufferStorageType::MUTABLE);
		~OpenGLVertexBuffer();

		virtual void Bind() const override;
		virtual void UnBind() const override;

		virtual void SetData(uint32_t size, const void* data) override;
		virtual void* MapBuffer(uint32_t size) override;
	private:
		uint32_t m_RendererID;
	};

	//--------------------------------------------------------------------
	//						Index Buffer
	//--------------------------------------------------------------------
	class OpenGLIndexBuffer :public IndexBuffer {
	public:

		OpenGLIndexBuffer(const uint32_t* data, uint32_t size);
		~OpenGLIndexBuffer();

		virtual void Bind() const override;
		virtual void UnBind() const override;

		virtual inline uint32_t GetCount() const override { return m_Elements; }

	private:
		uint32_t m_Elements;
		uint32_t m_RendererID;
	};
}