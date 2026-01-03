#pragma once

#include "Crimson/Renderer/Buffer.h"

namespace Crimson {
	class OpenGLVertexArray : public VertexArray
	{
	public:
		OpenGLVertexArray();
		~OpenGLVertexArray();
		virtual void Bind()const override;
		virtual void UnBind()const override;
		virtual void AddBuffer(Ref<BufferLayout>& layout, Ref<VertexBuffer>& vbo) override;
		virtual void SetIndexBuffer(Ref<IndexBuffer> IndexBuffer) override;

		virtual const Ref<IndexBuffer>& GetIndexBuffer() const override { return m_IndexBuffer; }
		virtual const std::vector<Ref<VertexBuffer>>& GetVertexBuffers() override { return m_VertexBuffer; }
		virtual GPUHandle GetVertexArrayHandle() override { return GPUHandle(m_RendererID); }
	private:
		std::vector<Ref<VertexBuffer>> m_VertexBuffer;
		Ref<IndexBuffer> m_IndexBuffer;
		uint32_t m_RendererID;
	};
}