#pragma once
#include <string>
#include "GPUHandle.h"

namespace Crimson {

	enum class BufferStorageType : uint8_t 
	{
		MUTABLE, IMMUTABLE
	};

	enum class ShaderDataType : uint8_t
	{
		None = 0,
		Float, Float2, Float3, Float4,
		Mat2, Mat3, Mat4,
		Int, Int2, Int3, Int4,
		Bool
	};


    static uint32_t GetComponentCount(ShaderDataType type)
    {
        switch (type)
        {
            case ShaderDataType::Float:   return 1;
            case ShaderDataType::Float2:  return 2;
            case ShaderDataType::Float3:  return 3;
            case ShaderDataType::Float4:  return 4;
            case ShaderDataType::Mat2:    return 2 * 2; 
            case ShaderDataType::Mat3:    return 3 * 3; 
            case ShaderDataType::Mat4:    return 4 * 4; 
            case ShaderDataType::Int:     return 1;
            case ShaderDataType::Int2:    return 2;
            case ShaderDataType::Int3:    return 3;
            case ShaderDataType::Int4:    return 4;
            case ShaderDataType::Bool:    return 1;
			case ShaderDataType::None:
			default:
				CN_CORE_ASSERT(false, "Unknown ShaderDataType!");
        }
        return 0;
    }


	static uint32_t ShaderDataTypeSize(ShaderDataType type)
    {
		uint32_t out_size = 0;
        switch (type)
        {
            case ShaderDataType::Float:    
            case ShaderDataType::Float2:   
            case ShaderDataType::Float3:   
            case ShaderDataType::Float4:   
            case ShaderDataType::Mat2:     
            case ShaderDataType::Mat3:     
            case ShaderDataType::Mat4:  
				out_size = sizeof(float);
				break;  
            case ShaderDataType::Int:    
            case ShaderDataType::Int2:     
            case ShaderDataType::Int3:     
            case ShaderDataType::Int4: 
				out_size = sizeof(int);
				break;
            case ShaderDataType::Bool:
				out_size = sizeof(bool);
				break;
			case ShaderDataType::None:
			default:
				CN_CORE_ASSERT(false, "Unknown Shader Data Type!");
        }

        return out_size * GetComponentCount(type);
    }

	/////////////////////
	struct BufferElements {

		std::string Name;
		ShaderDataType Type;
		size_t Offset;
		bool Normalized;

		BufferElements(std::string name, ShaderDataType type)
			:Type(type), Name(name), Offset(0), Normalized(false) {
		}
	};


	/////////////////////
	class BufferLayout {
	public:
		BufferLayout() = default;
		void push(std::string name, ShaderDataType type);

		inline std::vector<BufferElements*>& GetElements() { return m_Elements; }
		inline uint32_t GetStride() const { return Stride; }

	private:
		std::vector<BufferElements*> m_Elements;
		uint32_t Stride = 0;
	};

	////////////////////
	class VertexBuffer {
	public:
		virtual void Bind()const = 0;
		virtual void UnBind()const = 0;
		virtual void SetData(uint32_t size, const void* data) = 0;
		virtual void* MapBuffer(uint32_t size) = 0;

		static Ref<VertexBuffer> Create(const float* data, uint32_t size);
		static Ref<VertexBuffer> Create(uint32_t size, BufferStorageType Storage_Type = BufferStorageType::MUTABLE);
	};

	////////////////////
	class IndexBuffer {
	public:
		virtual void Bind() const = 0;
		virtual void UnBind() const = 0;
		virtual uint32_t GetCount() const = 0;

		static Ref<IndexBuffer> Create(const uint32_t* data, uint32_t size);
	};

	////////////////////
	class VertexArray {
	public:
		virtual void Bind()const = 0;
		virtual void UnBind()const = 0;
		virtual void AddBuffer(std::shared_ptr<BufferLayout>& layout, std::shared_ptr<VertexBuffer>& vbo) = 0;
		virtual void SetIndexBuffer(std::shared_ptr<IndexBuffer>) = 0;

		virtual const std::vector<std::shared_ptr<VertexBuffer>>& GetVertexBuffers() = 0;
		virtual const std::shared_ptr<IndexBuffer>& GetIndexBuffer() const = 0;
		virtual GPUHandle GetVertexArrayHandle() = 0;
		static Ref<VertexArray> Create();
	};

}