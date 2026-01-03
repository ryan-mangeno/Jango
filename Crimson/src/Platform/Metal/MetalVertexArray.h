#pragma once

#include "MetalVertexArray.h"
#include "Crimson/Renderer/Buffer.h"
namespace Crimson {

	class MetalVertexArray : public VertexArray
	{
	public:
		MetalVertexArray();
		~MetalVertexArray();
		virtual void Bind()const override;
		virtual void UnBind()const override;
		virtual void AddBuffer(Ref<BufferLayout>& layout, Ref<VertexBuffer>& vbo) override;
		virtual void SetIndexBuffer(Ref<IndexBuffer> IndexBuffer) override;
		virtual GPUHandle GetVertexArrayHandle() override { return GPUHandle(nullptr); } 
		virtual const Ref<IndexBuffer>& GetIndexBuffer() const override { return m_IndexBuffer; }
		virtual const std::vector<Ref<VertexBuffer>>& GetVertexBuffers() override { return m_VertexBuffer; }

	private:
		std::vector<Ref<VertexBuffer>> m_VertexBuffer;
		Ref<IndexBuffer> m_IndexBuffer;
	};


}