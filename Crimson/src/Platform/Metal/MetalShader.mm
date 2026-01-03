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
            
            case MTLDataTypeFloat2x2:   return ShaderDataType::Mat2;
            case MTLDataTypeFloat3x3:   return ShaderDataType::Mat3;
            case MTLDataTypeFloat4x4:   return ShaderDataType::Mat4;
            
            case MTLDataTypeBool:   return ShaderDataType::Bool;

            case MTLDataTypeArray:  
                CN_CORE_WARN("Array Type Not Implemented For Metal ...");
                return ShaderDataType::None; 
            case MTLDataTypeStruct: 
                CN_CORE_WARN("Struct Type Not Implemented For Metal ...");
                return ShaderDataType::None;
            default: 
                CN_CORE_WARN("MTLDataType not supported! ({0})", (int)type);
                return ShaderDataType::None;
        }
    }

    static MTLVertexFormat CrimsonToMetalVertexFormat(ShaderDataType type) {
        switch (type) {
            case ShaderDataType::Float:   return MTLVertexFormatFloat;
            case ShaderDataType::Float2:  return MTLVertexFormatFloat2;
            case ShaderDataType::Float3:  return MTLVertexFormatFloat3;
            case ShaderDataType::Float4:  return MTLVertexFormatFloat4;
            
            case ShaderDataType::Int:     return MTLVertexFormatInt;
            case ShaderDataType::Int2:    return MTLVertexFormatInt2;
            case ShaderDataType::Int3:    return MTLVertexFormatInt3;
            case ShaderDataType::Int4:    return MTLVertexFormatInt4;
            
            // MATRICES (Must be Invalid)
            // you cannot set a matrix format on a single vertex attribute slot
            // If you need instancing, you technically have to use 4 separate Float4 attributes
            case ShaderDataType::Mat2:    return MTLVertexFormatInvalid; 
            case ShaderDataType::Mat3:    return MTLVertexFormatInvalid; 
            case ShaderDataType::Mat4:    return MTLVertexFormatInvalid;
            
            case ShaderDataType::Bool:    return MTLVertexFormatUChar; // 1 byte
            
            default: return MTLVertexFormatInvalid;
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
                // fallback or others as needed
                default: return MTLVertexFormatFloat4; 
            }
        }

    // Get Size of Format (for calculating stride)
    static uint32_t GetMetalFormatSize(MTLVertexFormat format) {
        switch (format) {
            case MTLVertexFormatFloat:  return 4;
            case MTLVertexFormatFloat2: return 4 * 2;
            case MTLVertexFormatFloat3: return 4 * 3;
            case MTLVertexFormatFloat4: return 4 * 4;
            case MTLVertexFormatInt:    return 4;
            case MTLVertexFormatInt2:   return 4 * 2;
            case MTLVertexFormatInt3:   return 4 * 3;
            case MTLVertexFormatInt4:   return 4 * 4;
            default: return 0;
        }
    }

    std::string MetalShader::ParseFile(const std::string& filepath) {
        std::string result;
        std::ifstream in(filepath, std::ios::in | std::ios::binary);
        if (in)
        {
            in.seekg(0, std::ios::end);
            size_t size = in.tellg();
            if (size != -1)
            {
                result.resize(size);
                in.seekg(0, std::ios::beg);
                in.read(&result[0], size);
            }
            else
            {
                CN_CORE_ERROR("Could not read file '{0}'", filepath);
            }
        }
        else
        {
            CN_CORE_ERROR("Could not open file '{0}'", filepath);
        }
        return result;
    }

    MetalShader::MetalShader(const std::string& filepath)
        : m_Name("") {
        std::filesystem::path path(filepath);
        m_Name = path.stem().string();

        std::string source = ParseFile(filepath);
        
        CN_CORE_TRACE("Creating Shader: {0}", filepath.c_str());
        Compile(source, source);
    }
    

    MetalShader::MetalShader(const std::string& name, const std::string& vertexSrc, const std::string& fragmentSrc)
        : m_Name(name) {
        Compile(vertexSrc, fragmentSrc);
    }

    MetalShader::~MetalShader() {
        CFRelease(m_PipelineState);
        m_PipelineState = nullptr;
    }

    void MetalShader::Compile(const std::string& vertexSrc, const std::string& fragmentSrc) {
        NSError* error = nil;
        id<MTLDevice> mtlDevice = (__bridge id<MTLDevice>)MetalRendererAPI::GetDevice();
        
        // --- 1. Compile Vertex Shader ---
        NSString* nsVertSrc = [NSString stringWithUTF8String:vertexSrc.c_str()];
        id<MTLLibrary> vertLib = [mtlDevice newLibraryWithSource:nsVertSrc options:nil error:&error];
        if (error) {
            CN_CORE_ERROR("Metal Vertex Shader Error: {0}", [[error localizedDescription] UTF8String]);
            return;
        }

        // --- 2. Compile Fragment Shader ---
        NSString* nsFragSrc = [NSString stringWithUTF8String:fragmentSrc.c_str()];
        id<MTLLibrary> fragLib = [mtlDevice newLibraryWithSource:nsFragSrc options:nil error:&error];
        if (error) {
            CN_CORE_ERROR("Metal Fragment Shader Error: {0}", [[error localizedDescription] UTF8String]);
            return;
        }

        id<MTLFunction> vertFunc = [vertLib newFunctionWithName:@"vertex_main"];
        id<MTLFunction> fragFunc = [fragLib newFunctionWithName:@"fragment_main"];

        if (!vertFunc || !fragFunc) {
            CN_CORE_ERROR("Could not find 'vertex_main' or 'fragment_main' in shader!");
            return;
        }

        // --- 3. Configure Pipeline Descriptor ---
        MTLRenderPipelineDescriptor* pipelineDesc = [[MTLRenderPipelineDescriptor alloc] init];
        pipelineDesc.vertexFunction = vertFunc;
        pipelineDesc.fragmentFunction = fragFunc;

        // Auto-configure Vertex Descriptor based on Shader Inputs
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
            vertDesc.layouts[0].stepRate = 1;
            vertDesc.layouts[0].stepFunction = MTLVertexStepFunctionPerVertex;
            pipelineDesc.vertexDescriptor = vertDesc;
        }
        
        // Must match your RenderPass (Swapchain is BGRA8, Depth is Depth32Float)
        pipelineDesc.colorAttachments[0].pixelFormat = MTLPixelFormatBGRA8Unorm; 
        pipelineDesc.depthAttachmentPixelFormat = MTLPixelFormatDepth32Float;

        // --- 4. Create Pipeline State Object (PSO) with Reflection ---
        MTLRenderPipelineReflection* reflection = nil;
        id<MTLRenderPipelineState> pso = [mtlDevice newRenderPipelineStateWithDescriptor:pipelineDesc 
                                                                                    options:MTLPipelineOptionBufferTypeInfo 
                                                                                    reflection:&reflection 
                                                                                    error:&error];
        if (error) {
            CN_CORE_ERROR("Metal PSO Creation Error: {0}", [[error localizedDescription] UTF8String]);
        }
        
        m_PipelineState = (void*)CFBridgingRetain(pso); 

        // processing reflection        
        std::function<void(NSArray<MTLStructMember*>*, std::vector<uint8_t>&, uint32_t, bool, std::string)> ProcessMembers;
        
        ProcessMembers = [&](NSArray<MTLStructMember*>* members, std::vector<uint8_t>& buffer, uint32_t bufferIndex, bool isVertex, std::string prefix) 
        {
            for (MTLStructMember* member in members) 
            {
                std::string memberName = [member.name UTF8String];
                std::string fullName = prefix + memberName;

                // ARRAYS
                if (member.dataType == MTLDataTypeArray) 
                {
                    uint32_t arraySize = (uint32_t)(member.arrayType.arrayLength * member.arrayType.stride);
                    uint32_t endOffset = (uint32_t)member.offset + arraySize;
                    
                    // resize buffer to include the array memory
                    if (buffer.size() < endOffset) buffer.resize(endOffset);
                    
                    // for support for "Lights[0].Color", need another loop here
                    // For now, handling the memory size is the critical part.
                    continue; 
                }

                // NESTED STRUCTS 
                if (member.dataType == MTLDataTypeStruct)
                {
                    // RECURSE
                    // Pass the nested members and the new prefix "StructName."
                    ProcessMembers(member.structType.members, buffer, bufferIndex, isVertex, fullName + ".");
                    continue;
                }

                // STANDARD TYPES
                ShaderDataType crimsonType = MetalToCrimsonDataType(member.dataType);
                if (crimsonType == ShaderDataType::None) continue;

                uint32_t memb_size = ShaderDataTypeSize(crimsonType);

                UniformInfo info;
                info.Name = fullName; 
                info.Offset = (uint32_t)member.offset;
                info.Size = memb_size;
                info.BufferIndex = bufferIndex;
                info.IsVertex = isVertex;

                m_UniformMap[info.Name] = info;
                
                // Resize buffer
                if (buffer.size() < info.Offset + memb_size) {
                    buffer.resize(info.Offset + memb_size);
                }
            }
        };

        // Vertex 
        for (MTLArgument* arg in reflection.vertexArguments) {
            if (arg.type == MTLArgumentTypeBuffer && arg.bufferDataType == MTLDataTypeStruct) {
                if (arg.index >= 1) {
                    // Pass empty string as initial prefix
                    ProcessMembers(arg.bufferStructType.members, m_VertexUniformBuffer, (uint32_t)arg.index, true, "");
                }
            }
        }

        // Frag
        for (MTLArgument* arg in reflection.fragmentArguments) {
            if (arg.type == MTLArgumentTypeBuffer && arg.bufferDataType == MTLDataTypeStruct) {
                if (arg.index >= 1) {
                    ProcessMembers(arg.bufferStructType.members, m_FragmentUniformBuffer, (uint32_t)arg.index, false, "");
                }
            }
        }
    }

    void MetalShader::Bind() const {
        // assume the Renderer calls [encoder setRenderPipelineState:m_PipelineState]
    }

    void MetalShader::UnBind() const {
        // No op in Metal
    }

    // The UploadUniforms() function will send it to GPU later
    void MetalShader::SetFloat(const std::string& name, const float& value) {
        SetUniform<float>(name, value);
    }

    void MetalShader::SetInt(const std::string& name, const int& value) {
        SetUniform<int>(name, value);
    }

    void MetalShader::SetFloat3(const std::string& name, const glm::vec3& value) {
        SetUniform<glm::vec3>(name, value);
    }
    
    void MetalShader::SetFloat4(const std::string& name, const glm::vec4& value) {
        SetUniform<glm::vec4>(name, value);
    }

    void MetalShader::SetMat4(const std::string& name, const glm::mat4& value, size_t count) {
        SetUniform<glm::mat4>(name, value);
    }
        
    
    void MetalShader::UploadUniforms(void* rawEncoder) {
        id<MTLRenderCommandEncoder> encoder = (__bridge id<MTLRenderCommandEncoder>)rawEncoder;

        // bind pipeline state
        [encoder setRenderPipelineState:(__bridge id<MTLRenderPipelineState>)m_PipelineState];

        // send Bytes directly to GPU (Best for < 4KB data per frame)
        // would typically hardcode the buffer index for uniforms
        // or store it in the UniformInfo
        if (!m_VertexUniformBuffer.empty()) {
            [encoder setVertexBytes:m_VertexUniformBuffer.data() 
                             length:m_VertexUniformBuffer.size() 
                            atIndex:1]; // assuming index 1 is for Uniforms
        }
        
        if (!m_FragmentUniformBuffer.empty()) {
            [encoder setFragmentBytes:m_FragmentUniformBuffer.data() 
                               length:m_FragmentUniformBuffer.size() 
                              atIndex:1];
        }
    }

}