#pragma once

#include "Crimson/Renderer/Shader.h"

#include <unordered_map>

namespace Crimson {

    class MetalShader : public Shader {
    public:
        MetalShader(const std::string& filepath);
        MetalShader(const std::string& name, const std::string& vertexSrc, const std::string& fragmentSrc);
        virtual ~MetalShader();

        virtual void Bind() const override;
        virtual void UnBind() const override;

        virtual void SetInt(const std::string& name, const int& value) override;
        
        virtual void SetFloat(const std::string& name, const float& value) override;
        virtual void SetFloat3(const std::string& name, const glm::vec3& value) override;
        virtual void SetFloat4(const std::string& name, const glm::vec4& value) override;
        virtual void SetMat4(const std::string& name, const glm::mat4& value, size_t count = 1) override;
        
        // Unimplemented arrays for brevity, but they follow the same pattern
        virtual void SetIntArray(const std::string& name, const size_t size, const void* values) override {};
        virtual void SetFloatArray(const std::string& name, float& values, size_t count) override {}
        virtual void SetFloat3Array(const std::string& name, const float* values, size_t count) override {}
        virtual void SetFloat4Array(const std::string& name, const float* values, size_t count) override {}

        virtual const std::string& GetName() const override { return m_Name; }
        
        // Internal method to push the CPU buffer to the GPU Command Encoder
        // This should be called by your Renderer before the Draw call
        void UploadUniforms(void* commandEncoder);

    private:

        std::string ParseFile(const std::string& filepath);
        void Compile(const std::string& vertexSrc, const std::string& fragmentSrc);

        struct UniformInfo {
            std::string Name;
            uint32_t Offset;
            uint32_t Size;
            uint32_t BufferIndex; 
            bool IsVertex;        // true = vertex, false = fragment
        };

        template<typename T>
        void SetUniform(const std::string& name, const T& value) {
            if (m_UniformMap.find(name) != m_UniformMap.end()) {
                const UniformInfo& info = m_UniformMap.at(name);
                std::vector<uint8_t>& buffer = info.IsVertex ? m_VertexUniformBuffer : m_FragmentUniformBuffer;
                if (buffer.size() < info.Offset + sizeof(T)) buffer.resize(info.Offset + sizeof(T));
                memcpy(buffer.data() + info.Offset, &value, sizeof(T));
            }
        }

    private:
        std::string m_Name;
        
        void* m_PipelineState; // id<MTLRenderPipelineState>
        
        // We use mutable so Set* methods can remain const to match the interface
        mutable std::vector<uint8_t> m_VertexUniformBuffer;
        mutable std::vector<uint8_t> m_FragmentUniformBuffer;
        mutable std::unordered_map<std::string, UniformInfo> m_UniformMap;
    };
}