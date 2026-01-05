#include "cnpch.h"
#include "MetalShader.h"
#include "MetalRendererAPI.h"
#include "Crimson/Core/Core.h" 
#include "Crimson/Core/Log.h" 

#import <Metal/Metal.h>

namespace Crimson {

    static ShaderDataType MetalToCrimsonDataType(MTLDataType type) {
        switch (type) {
            case MTLDataTypeFloat:  return ShaderDataType::Float;
            case MTLDataTypeFloat2: return ShaderDataType::Float2;
            case MTLDataTypeFloat3: return ShaderDataType::Float3;
            case MTLDataTypeFloat4: return ShaderDataType::Float4;
            case MTLDataTypeInt:    return ShaderDataType::Int;
            case MTLDataTypeInt2:   return ShaderDataType::Int2;
            case MTLDataTypeInt3:   return ShaderDataType::Int3;
            case MTLDataTypeInt4:   return ShaderDataType::Int4;
            case MTLDataTypeFloat2x2: return ShaderDataType::Mat2;
            case MTLDataTypeFloat3x3: return ShaderDataType::Mat3;
            case MTLDataTypeFloat4x4: return ShaderDataType::Mat4;
            case MTLDataTypeBool:   return ShaderDataType::Bool;
            default: return ShaderDataType::None;
        }
    }

    static MTLVertexFormat GetMetalFormatFromAttributeType(MTLDataType type) {
        switch (type) {
            case MTLDataTypeFloat:  return MTLVertexFormatFloat;
            case MTLDataTypeFloat2: return MTLVertexFormatFloat2;
            case MTLDataTypeFloat3: return MTLVertexFormatFloat3;
            case MTLDataTypeFloat4: return MTLVertexFormatFloat4;
            case MTLDataTypeInt:    return MTLVertexFormatInt;
            case MTLDataTypeInt2:   return MTLVertexFormatInt2;
            case MTLDataTypeInt3:   return MTLVertexFormatInt3;
            case MTLDataTypeInt4:   return MTLVertexFormatInt4;
            default: return MTLVertexFormatFloat4; 
        }
    }

    static uint32_t GetMetalFormatSize(MTLVertexFormat format) {
        switch (format) {
            case MTLVertexFormatFloat:  return 4;
            case MTLVertexFormatFloat2: return 8;
            case MTLVertexFormatFloat3: return 12;
            case MTLVertexFormatFloat4: return 16;
            case MTLVertexFormatInt:    return 4;
            case MTLVertexFormatInt2:   return 8;
            case MTLVertexFormatInt3:   return 12;
            case MTLVertexFormatInt4:   return 16;
            default: return 0;
        }
    }

    std::string MetalShader::ParseFile(const std::string& filepath) {
        std::string result;
        std::ifstream in(filepath, std::ios::in | std::ios::binary);
        if (in) {
            in.seekg(0, std::ios::end);
            size_t size = in.tellg();
            if (size != -1) {
                result.resize(size);
                in.seekg(0, std::ios::beg);
                in.read(&result[0], size);
            }
        }
        return result;
    }

    MetalShader::MetalShader(const std::string& filepath) : m_Name(""), m_IsCompute(false) {
        std::filesystem::path path(filepath);
        m_Name = path.stem().string();
        std::string source = ParseFile(filepath);
        Compile(source, source);
    }
    
    MetalShader::MetalShader(const std::string& name, const std::string& vertexSrc, const std::string& fragmentSrc) : m_Name(name), m_IsCompute(false) {
        Compile(vertexSrc, fragmentSrc);
    }

    MetalShader::~MetalShader() {
        if (m_PipelineState) CFRelease(m_PipelineState);
        if (m_ComputePipelineState) CFRelease(m_ComputePipelineState);
    }

    void MetalShader::Compile(const std::string& vertexSrc, const std::string& fragmentSrc) {
        NSError* error = nil;
        id<MTLDevice> mtlDevice = (__bridge id<MTLDevice>)MetalRendererAPI::GetDevice();
        
        // lambda to process structural reflection recursively
        std::function<void(NSArray<MTLStructMember*>*, std::vector<uint8_t>&, uint32_t, ShaderType, std::string)> ProcessMembers;
        
        ProcessMembers = [&](NSArray<MTLStructMember*>* members, std::vector<uint8_t>& buffer, uint32_t bufferIndex, ShaderType type, std::string prefix) 
        {
            for (MTLStructMember* member in members) 
            {
                std::string fullName = prefix + [member.name UTF8String];

                if (member.dataType == MTLDataTypeArray) {
                    uint32_t arraySize = (uint32_t)(member.arrayType.arrayLength * member.arrayType.stride);
                    uint32_t endOffset = (uint32_t)member.offset + arraySize;
                    if (buffer.size() < endOffset) buffer.resize(endOffset);
                    continue; 
                }

                if (member.dataType == MTLDataTypeStruct) {
                    ProcessMembers(member.structType.members, buffer, bufferIndex, type, fullName + ".");
                    continue;
                }

                ShaderDataType crimsonType = MetalToCrimsonDataType(member.dataType);
                if (crimsonType == ShaderDataType::None) continue;

                uint32_t memb_size = ShaderDataTypeSize(crimsonType);

                // using updated UniformInfo struct with ShaderType
                UniformInfo info = { fullName, (uint32_t)member.offset, memb_size, bufferIndex, type };

                m_UniformMap[info.Name] = info;
                
                if (buffer.size() < info.Offset + memb_size) {
                    buffer.resize(info.Offset + memb_size);
                }
            }
        };

        // compile source library
        NSString* nsSrc = [NSString stringWithUTF8String:vertexSrc.c_str()];
        id<MTLLibrary> library = [mtlDevice newLibraryWithSource:nsSrc options:nil error:&error];
        if (error) {
            CN_CORE_ERROR("Metal Compile Error: {0}", [[error localizedDescription] UTF8String]);
            return;
        }

        // attempt to load compute kernel
        id<MTLFunction> computeFunc = [library newFunctionWithName:@"compute_main"];
        
        if (computeFunc) 
        {
            // --- COMPUTE PIPELINE ---
            m_IsCompute = true;

            MTLComputePipelineDescriptor* computeDesc = [[MTLComputePipelineDescriptor alloc] init];
            computeDesc.computeFunction = computeFunc;

            MTLComputePipelineReflection* reflection = nil;
            id<MTLComputePipelineState> pso = [mtlDevice newComputePipelineStateWithDescriptor:computeDesc 
                                                                                       options:MTLPipelineOptionBufferTypeInfo 
                                                                                    reflection:&reflection 
                                                                                         error:&error];
            if (error) {
                CN_CORE_ERROR("Metal Compute PSO Error: {0}", [[error localizedDescription] UTF8String]);
                return;
            }
            m_ComputePipelineState = (void*)CFBridgingRetain(pso);

            // reflect compute uniforms
            for (MTLArgument* arg in reflection.arguments) {
                if (arg.type == MTLArgumentTypeBuffer && arg.bufferDataType == MTLDataTypeStruct) {
                    // map to vertex uniform buffer for storage
                    ProcessMembers(arg.bufferStructType.members, m_VertexUniformBuffer, (uint32_t)arg.index, ShaderType::Compute, "");
                }
            }
        }
        else 
        {
            // --- GRAPHICS PIPELINE ---
            m_IsCompute = false;
            
            id<MTLLibrary> fragLib = library;
            if (vertexSrc != fragmentSrc) {
                 NSString* nsFragSrc = [NSString stringWithUTF8String:fragmentSrc.c_str()];
                 fragLib = [mtlDevice newLibraryWithSource:nsFragSrc options:nil error:&error];
            }

            id<MTLFunction> vertFunc = [library newFunctionWithName:@"vertex_main"];
            id<MTLFunction> fragFunc = [fragLib newFunctionWithName:@"fragment_main"];

            if (!vertFunc || !fragFunc) {
                CN_CORE_ERROR("Shader '{0}' missing entry points!", m_Name);
                return;
            }

            MTLRenderPipelineDescriptor* pipelineDesc = [[MTLRenderPipelineDescriptor alloc] init];
            pipelineDesc.vertexFunction = vertFunc;
            pipelineDesc.fragmentFunction = fragFunc;

            // vertex descriptor
            if (vertFunc.vertexAttributes.count > 0) {
                MTLVertexDescriptor* vertDesc = [[MTLVertexDescriptor alloc] init];
                uint32_t currentOffset = 0;
                for (MTLVertexAttribute* attr in vertFunc.vertexAttributes) {
                    if (attr.active) {
                        uint32_t index = (uint32_t)attr.attributeIndex;
                        MTLVertexFormat format = GetMetalFormatFromAttributeType(attr.attributeType);
                        vertDesc.attributes[index].format = format;
                        vertDesc.attributes[index].offset = currentOffset;
                        vertDesc.attributes[index].bufferIndex = 0; 
                        currentOffset += GetMetalFormatSize(format);
                    }
                }
                vertDesc.layouts[0].stride = currentOffset;
                pipelineDesc.vertexDescriptor = vertDesc;
            }
            
            pipelineDesc.colorAttachments[0].pixelFormat = MTLPixelFormatBGRA8Unorm; 
            pipelineDesc.depthAttachmentPixelFormat = MTLPixelFormatDepth32Float;

            MTLRenderPipelineReflection* reflection = nil;
            id<MTLRenderPipelineState> pso = [mtlDevice newRenderPipelineStateWithDescriptor:pipelineDesc 
                                                                                        options:MTLPipelineOptionBufferTypeInfo 
                                                                                     reflection:&reflection 
                                                                                        error:&error];
            if (error) CN_CORE_ERROR("Metal Render PSO Error: {0}", [[error localizedDescription] UTF8String]);
            
            m_PipelineState = (void*)CFBridgingRetain(pso); 

            // reflect graphics uniforms
            for (MTLArgument* arg in reflection.vertexArguments) {
                if (arg.type == MTLArgumentTypeBuffer && arg.bufferDataType == MTLDataTypeStruct && arg.index >= 1) {
                    ProcessMembers(arg.bufferStructType.members, m_VertexUniformBuffer, (uint32_t)arg.index, ShaderType::Vertex, "");
                }
            }
            for (MTLArgument* arg in reflection.fragmentArguments) {
                if (arg.type == MTLArgumentTypeBuffer && arg.bufferDataType == MTLDataTypeStruct && arg.index >= 1) {
                    ProcessMembers(arg.bufferStructType.members, m_FragmentUniformBuffer, (uint32_t)arg.index, ShaderType::Fragment, "");
                }
            }
        }
    }

    void MetalShader::Bind() const {
        // no-op, handled in UploadUniforms or Renderer
    }

    void MetalShader::UnBind() const {}

    void MetalShader::SetFloat(const std::string& name, const float& value) { SetUniform<float>(name, value); }
    void MetalShader::SetInt(const std::string& name, const int& value) { SetUniform<int>(name, value); }
    void MetalShader::SetFloat3(const std::string& name, const glm::vec3& value) { SetUniform<glm::vec3>(name, value); }
    void MetalShader::SetFloat4(const std::string& name, const glm::vec4& value) { SetUniform<glm::vec4>(name, value); }
    void MetalShader::SetMat4(const std::string& name, const glm::mat4& value, size_t count) { SetUniform<glm::mat4>(name, value); }
    
    void MetalShader::UploadUniforms(void* rawEncoder) {
        if (m_IsCompute) {
            id<MTLComputeCommandEncoder> encoder = (__bridge id<MTLComputeCommandEncoder>)rawEncoder;
            [encoder setComputePipelineState:(__bridge id<MTLComputePipelineState>)m_ComputePipelineState];

            // uploading compute uniforms to index 4 (standard for crimson compute shaders)
            if (!m_VertexUniformBuffer.empty()) {
                [encoder setBytes:m_VertexUniformBuffer.data() 
                           length:m_VertexUniformBuffer.size() 
                          atIndex:4]; 
            }
        } 
        else {
            id<MTLRenderCommandEncoder> encoder = (__bridge id<MTLRenderCommandEncoder>)rawEncoder;
            [encoder setRenderPipelineState:(__bridge id<MTLRenderPipelineState>)m_PipelineState];

            // uploading graphics uniforms to index 1
            if (!m_VertexUniformBuffer.empty()) {
                [encoder setVertexBytes:m_VertexUniformBuffer.data() length:m_VertexUniformBuffer.size() atIndex:1];
            }
            if (!m_FragmentUniformBuffer.empty()) {
                [encoder setFragmentBytes:m_FragmentUniformBuffer.data() length:m_FragmentUniformBuffer.size() atIndex:1];
            }
        }
    }
}