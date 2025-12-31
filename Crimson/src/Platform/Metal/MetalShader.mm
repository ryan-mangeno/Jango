#include "cnpch.h"

#include "MetalShader.h"
#include "MetalContext.h"
#include "MetalRendererAPI.h"

#import <Metal/Metal.h>
#include <fstream>
#include <filesystem>

#include <glm/gtc/type_ptr.hpp>

namespace Crimson {

    static std::string ExtractName(const std::string& filepath)
    {
        return std::filesystem::path(filepath).stem().string();
    }

    MetalShader::MetalShader(const std::string& filepath)
        : m_FilePath(filepath), m_Name(ExtractName(filepath))
    {
        ShaderSources sources = ParseFile(filepath);
        Compile(sources);
    }

    MetalShader::MetalShader(const std::string& name, const std::string& vertexSrc, const std::string& fragmentSrc)
        : m_Name(name)
    {
        ShaderSources sources;
        sources.VertexSource = vertexSrc;
        sources.FragmentSource = fragmentSrc;
        Compile(sources);
    }

    MetalShader::~MetalShader()
    {
        // arc handles Metal object release
        m_Pipeline = nullptr;
    }

    // COMPILATION & REFLECTION
    void MetalShader::Compile(const ShaderSources& sources)
    {
        id<MTLDevice> device = (__bridge id<MTLDevice>)MetalRendererAPI::GetDevice();
        NSError* error = nil;

        // combine sources into one MSL string 
        std::string fullSource = sources.VertexSource + "\n" + sources.FragmentSource;
        if (sources.VertexSource.empty() && sources.FragmentSource.empty()) {
            // Fallback for when ParseFile returns empty (e.g. single file without #shader tags)
            std::ifstream stream(m_FilePath);
            std::stringstream buffer;
            buffer << stream.rdbuf();
            fullSource = buffer.str();
        }

        NSString* nsSource = [NSString stringWithUTF8String:fullSource.c_str()];
        
        // compile lib
        id<MTLLibrary> library = [device newLibraryWithSource:nsSource options:nil error:&error];
        if (!library) {
            CN_CORE_ERROR("Metal Shader Compilation Failure ({0}):\n{1}", m_Name, [error.localizedDescription UTF8String]);
            return;
        }

        // pipeline desc
        // assume standard entry point names "vertex_main" and "fragment_main"
        // must ensure.metal shaders use these function names
        id<MTLFunction> vertFunc = [library newFunctionWithName:@"vertex_main"];
        id<MTLFunction> fragFunc = [library newFunctionWithName:@"fragment_main"];
        
        if (!vertFunc || !fragFunc) {
            CN_CORE_ERROR("Could not find 'vertex_main' or 'fragment_main' in shader: {0}", m_Name);
            return;
        }

        MTLRenderPipelineDescriptor* pipelineDesc = [[MTLRenderPipelineDescriptor alloc] init];
        pipelineDesc.vertexFunction = vertFunc;
        pipelineDesc.fragmentFunction = fragFunc;
        
        // setup standard attachments , has to match with Renderer/Swapchain
        pipelineDesc.colorAttachments[0].pixelFormat = MTLPixelFormatBGRA8Unorm; // standard screen fmt
        pipelineDesc.colorAttachments[0].blendingEnabled = YES;
        pipelineDesc.colorAttachments[0].sourceRGBBlendFactor = MTLBlendFactorSourceAlpha;
        pipelineDesc.colorAttachments[0].destinationRGBBlendFactor = MTLBlendFactorOneMinusSourceAlpha;
        pipelineDesc.depthAttachmentPixelFormat = MTLPixelFormatDepth32Float;

        // create pipeline state with reflection
        MTLRenderPipelineReflection* reflection = nil;
        id<MTLRenderPipelineState> pso = [device newRenderPipelineStateWithDescriptor:pipelineDesc 
                                                                             options:MTLPipelineOptionBufferTypeInfo 
                                                                          reflection:&reflection 
                                                                               error:&error];

        if (!pso) {
            CN_CORE_ERROR("Pipeline Creation Failed ({0}): {1}", m_Name, [error.localizedDescription UTF8String]);
            return;
        }

        m_Pipeline = (__bridge_retained void*)pso;

        // building uniform map
        m_UniformMap.clear();

        // Helper lambda to parse arguments
        auto parseArgs = [&](NSArray<MTLArgument*>* args, int stage) {
            for (MTLArgument* arg in args) {
                if (arg.type == MTLArgumentTypeBuffer) {
                    // found a struct (Uniform Buffer)
                    // only support one uniform buffer per stage for simplicity (Buffer Index 0 or 1)
                    size_t bufferSize = arg.bufferDataSize;
                    
                    if (stage == 0) m_VSUniformBuffer.resize(bufferSize); // Vertex
                    else            m_FSUniformBuffer.resize(bufferSize); // Fragment
                    
                    // Iterate members of the struct
                    for (MTLStructMember* member in arg.bufferStructType.members) {
                        UniformInfo info;
                        info.Stage = stage;
                        info.Offset = member.offset;
                        info.Size = 0; // Can be inferred if needed
                        
                        // Map "u_ViewProjection" -> Offset 0
                        std::string name = [member.name UTF8String];
                        m_UniformMap[name] = info;
                    }
                }
            }
        };

        parseArgs(reflection.vertexArguments, 0);   // Stage 0 = Vertex
        parseArgs(reflection.fragmentArguments, 1); // Stage 1 = Fragment
    }
    // BINDING
    void MetalShader::Bind() const
    {
        // get encoder
        // metal context must track the active render encoder for the current frame
        id<MTLRenderCommandEncoder> encoder = (__bridge id<MTLRenderCommandEncoder>)MetalRendererAPI::GetCurrentEncoder();
        if (!encoder) return;

        // set pipeline
        [encoder setRenderPipelineState:(__bridge id<MTLRenderPipelineState>)m_Pipeline];

        // upload Uniforms (Vertex)
        if (!m_VSUniformBuffer.empty()) {
            [encoder setVertexBytes:m_VSUniformBuffer.data() 
                             length:m_VSUniformBuffer.size() 
                            atIndex:1]; // convention: Index 1 is Uniforms
        }

        // upload uniforms (Fragment)
        if (!m_FSUniformBuffer.empty()) {
            [encoder setFragmentBytes:m_FSUniformBuffer.data() 
                               length:m_FSUniformBuffer.size() 
                              atIndex:1]; // convention: Index 1 is Uniforms
        }
    }

    void MetalShader::UnBind() const
    {
        // Metal doesn't really "Unbind", we just stop encoding or bind something else
    }

    // UNIFORM SETTERS (Write to CPU Buffer)
    void MetalShader::SetUniformData(const std::string& name, const void* data, size_t size) const
    {
        auto it = m_UniformMap.find(name);
        if (it != m_UniformMap.end()) 
        {
            const UniformInfo& info = it->second;
            std::vector<uint8_t>& buffer = (info.Stage == 0) ? m_VSUniformBuffer : m_FSUniformBuffer;
            
            // Safety check
            if (info.Offset + size <= buffer.size()) {
                memcpy(&buffer[info.Offset], data, size);
            }
        }
    }

    void MetalShader::SetMat4(const std::string& str, const glm::mat4& val, size_t count) const {
        SetUniformData(str, glm::value_ptr(val), sizeof(glm::mat4));
    }
    void MetalShader::SetInt(const std::string& str, const int& val) const {
        SetUniformData(str, &val, sizeof(int));
    }
    void MetalShader::SetFloat(const std::string& str, const float& val) const {
        SetUniformData(str, &val, sizeof(float));
    }
    void MetalShader::SetFloat3(const std::string& str, const glm::vec3& val) const {
        SetUniformData(str, glm::value_ptr(val), sizeof(glm::vec3));
    }
    void MetalShader::SetFloat4(const std::string& str, const glm::vec4& val) const {
        SetUniformData(str, glm::value_ptr(val), sizeof(glm::vec4));
    }
    
    // Arrays (Simplification: Just copy assuming packed layout)
    void MetalShader::SetIntArray(const std::string& str, const size_t size, const void* pointer) const {
        SetUniformData(str, pointer, sizeof(int) * size);
    }
    void MetalShader::SetFloatArray(const std::string& str, float& val, size_t count) const {
        SetUniformData(str, &val, sizeof(float) * count);
    }
    void MetalShader::SetFloat3Array(const std::string& str, const float* pointer, size_t count) const {
        SetUniformData(str, pointer, sizeof(glm::vec3) * count);
    }
    void MetalShader::SetFloat4Array(const std::string& str, const float* pointer, size_t count) const {
        SetUniformData(str, pointer, sizeof(glm::vec4) * count);
    }

    // PARSER (Legacy support for split files)
    ShaderSources MetalShader::ParseFile(const std::string& path)
    {
        std::ifstream stream(path);
        if (!stream) {
            CN_CORE_ERROR("Shader File Not Found: {0}", path);
            return {};
        }

        std::string line;
        std::stringstream ss[3]; // 0=Vertex, 1=Frag, 2=Compute
        int index = -1;

        // default to Vertex if no tag found (for single file MSL)
        bool tagFound = false;

        while (getline(stream, line))
        {
            if (line.find("#shader vertex") != std::string::npos) {
                index = 0; tagFound = true;
            }
            else if (line.find("#shader fragment") != std::string::npos) {
                index = 1; tagFound = true;
            }
            else if (line.find("#shader compute") != std::string::npos) {
                index = 2; tagFound = true;
            }
            else {
                if (index != -1) ss[index] << line << '\n';
                else if (!tagFound) ss[0] << line << '\n'; // Dump everything to Vertex src if no tags
            }
        }
        
        return { ss[0].str(), ss[1].str(), ss[2].str() };
    }
}