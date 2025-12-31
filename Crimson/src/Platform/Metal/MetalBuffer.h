#pragma once

#include "Crimson/Renderer/Buffer.h"

namespace Crimson {


	// --------------------------------------------------------------------
	//							Vertex Buffer
	// --------------------------------------------------------------------


	class MetalVertexBuffer :public VertexBuffer {
	public:

		MetalVertexBuffer(const float* data, uint32_t size);
		MetalVertexBuffer(uint32_t size, BufferStorageType Storage_Type = BufferStorageType::MUTABLE);
		~MetalVertexBuffer();

		virtual void Bind() const override;
		virtual void UnBind() const override;

		virtual void SetData(uint32_t size, const void* data) override;
		virtual void* MapBuffer(uint32_t size) override;
	private:
		unsigned int m_RendererID;
	};

	// 	// --------------------------------------------------------------------
	// 	//							Index Buffer
	// 	// --------------------------------------------------------------------
	class MetalIndexBuffer :public IndexBuffer {
	public:

		MetalIndexBuffer(const uint32_t* data, uint32_t size);
		~MetalIndexBuffer();

		void Bind() const override;
		void UnBind() const override;

		inline uint32_t GetCount() override { return m_Elements; }

	private:
		uint32_t m_Elements;
		unsigned int m_RendererID;
	};
}