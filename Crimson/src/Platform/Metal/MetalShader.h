#pragma once

#include "Crimson/Renderer/Shader.h"
#include <string>
#include <unordered_map>
#include <vector>

namespace Crimson {

    struct ShaderSources 
    {
        std::string VertexSource;
        std::string FragmentSource;
        std::string ComputeSource;
    };

    // helper to track where a uniform lives in our CPU buffer
    struct UniformInfo
    {
        // does this uniform belong to Vertex (0) or Fragment (1) stage?
        int Stage; 
        // offset in bytes into the buffer
        size_t Offset;
        // size of the data (ex 64 for mat4)
        size_t Size;
    };

    class MetalShader : public Shader 
    {
    public:
        MetalShader(const std::string& filepath);
        MetalShader(const std::string& name, const std::string& vertexSrc, const std::string& fragmentSrc);
        virtual ~MetalShader();

        virtual void Bind() const override;
        virtual void UnBind() const override;

        // Uniform Setters
        // In OpenGL, these called glUniform directly.
        // In Metal, these will update a CPU-side "scratch buffer" (m_VSBuffer/m_FSBuffer)
        // which gets uploaded to the GPU automatically during Bind()
        virtual void SetMat4(const std::string& str, const glm::mat4& val, size_t count = 1) const override;
        virtual void SetInt(const std::string& str, const int& val) const override;
        virtual void SetIntArray(const std::string& str, const size_t size, const void* pointer) const override;
        virtual void SetFloat(const std::string& str, const float& val) const override;
        virtual void SetFloatArray(const std::string& str, float& val, size_t count) const override;
        virtual void SetFloat4(const std::string& str, const glm::vec4& val) const override;
        virtual void SetFloat4Array(const std::string& str, const float* arr, size_t count) const override;
        virtual void SetFloat3(const std::string& str, const glm::vec3& val) const override;
        virtual void SetFloat3Array(const std::string& str, const float* pointer, size_t count)  const override;

        virtual const std::string& GetName() const override { return m_Name; }

        //internal Accessors for the Renderer
        // Returns (id<MTLRenderPipelineState>) cast to void*
        void* GetRenderPipelineState() const { return m_Pipeline; }
        // Returns (id<MTLComputePipelineState>) cast to void*
        void* GetComputePipelineState() const { return m_ComputePipeline; }

        // Returns pointer to the raw data buffers so the Renderer can bind them
        void* GetVSBufferData() const { return (void*)m_VSUniformBuffer.data(); }
        size_t GetVSBufferSize() const { return m_VSUniformBuffer.size(); }
        
        void* GetFSBufferData() const { return (void*)m_FSUniformBuffer.data(); }
        size_t GetFSBufferSize() const { return m_FSUniformBuffer.size(); }

    private:
        // Reads file and splits into Vertex/Fragment/Compute strings
        ShaderSources ParseFile(const std::string& path);
        
        // Compiles source strings into a Metal Pipeline State
        void Compile(const ShaderSources& sources);
        
        // Scans the source code to find where uniforms are (Reflection)
        // e.g., Finds that "u_ViewProjection" is at offset 0 in the struct
        void Reflect(const std::string& vertexSrc, const std::string& fragmentSrc);
        
        // Helper to write data into our CPU cache
        void SetUniformData(const std::string& name, const void* data, size_t size) const;

    private:
        std::string m_Name;
        std::string m_FilePath;

        void* m_Pipeline = nullptr;        // id<MTLRenderPipelineState>
        void* m_ComputePipeline = nullptr; // id<MTLComputePipelineState>

        // Uniform Emulation
        // Map: Name -> {Stage, Offset, Size}
        std::unordered_map<std::string, UniformInfo> m_UniformMap;
        
        // CPU-side cache of uniform data
        // Marked mutable because SetMat4 is const in the base class, 
        // but we need to update these internal buffers
        mutable std::vector<uint8_t> m_VSUniformBuffer; // Vertex Shader Uniforms
        mutable std::vector<uint8_t> m_FSUniformBuffer; // Fragment Shader Uniforms
    };
}