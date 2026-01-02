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
            
            default: 
                CN_CORE_ERROR("MTLDataType not supported!");
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
            // you cannot set a "Matrix" format on a single vertex attribute slot
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
        
        NSString* nsVertSrc = [NSString stringWithUTF8String:vertexSrc.c_str()];
        id<MTLLibrary> vertLib = [mtlDevice newLibraryWithSource:nsVertSrc options:nil error:&error];
        if (error) {
            CN_CORE_ERROR("Metal Vertex Shader Error: {0}", [[error localizedDescription] UTF8String]);
            return;
        }

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

        MTLRenderPipelineDescriptor* pipelineDesc = [[MTLRenderPipelineDescriptor alloc] init];
        pipelineDesc.vertexFunction = vertFunc;
        pipelineDesc.fragmentFunction = fragFunc;

        if (vertFunc.vertexAttributes.count > 0) {
            MTLVertexDescriptor* vertDesc = [[MTLVertexDescriptor alloc] init];
            
            uint32_t currentOffset = 0;
            
            for (MTLVertexAttribute* attr in vertFunc.vertexAttributes) {
                if (attr.active) {
                    // get the idx ([[attribute(0)]])
                    uint32_t index = attr.attributeIndex;

                    // determine fmt dynamically
                    MTLVertexFormat format = GetMetalFormatFromAttributeType(attr.attributeType);
                    vertDesc.attributes[index].format = format;
                    
                    // set Offset & Buffer
                    // pack them tightly for the Reflection PSO.
                    // (Actual rendering might use a different layout, but this lets us compile)
                    vertDesc.attributes[index].offset = currentOffset;
                    vertDesc.attributes[index].bufferIndex = 0; 
                    
                    // advance Offset
                    currentOffset += GetMetalFormatSize(format);
                }
            }
            // set total stride
            vertDesc.layouts[0].stride = currentOffset;
            vertDesc.layouts[0].stepRate = 1;
            vertDesc.layouts[0].stepFunction = MTLVertexStepFunctionPerVertex;
            
            pipelineDesc.vertexDescriptor = vertDesc;
        }
        
        // must match FrameBuffer
        pipelineDesc.colorAttachments[0].pixelFormat = MTLPixelFormatBGRA8Unorm; 
        pipelineDesc.depthAttachmentPixelFormat = MTLPixelFormatDepth32Float;

        // create state with Reflection
        MTLRenderPipelineReflection* reflection = nil;
        id<MTLRenderPipelineState> pso = [mtlDevice newRenderPipelineStateWithDescriptor:pipelineDesc 
                                                                                    options:MTLPipelineOptionBufferTypeInfo 
                                                                                    reflection:&reflection 
                                                                                    error:&error];
        if (error) {
            CN_CORE_ERROR("Metal PSO Creation Error: {0}", [[error localizedDescription] UTF8String]);
        }
        
        m_PipelineState = (void*)CFBridgingRetain(pso); // transfer ownership to C++

        // Process reflection to build our uniform map
        // we look at the arguments to find our uniforms struct
        for (MTLArgument* arg in reflection.vertexArguments) {
            if (arg.type == MTLArgumentTypeBuffer) {
                // if this is the uniform buffer
                // we iterate its members
                if (arg.bufferDataType == MTLDataTypeStruct) {
                    for (MTLStructMember* member in arg.bufferStructType.members) {
                        
                        uint32_t memb_size = ShaderDataTypeSize(MetalToCrimsonDataType(member.dataType));

                        UniformInfo info;
                        info.Name = [member.name UTF8String];
                        info.Offset = (uint32_t)member.offset;
                        info.Size = memb_size;
                        info.BufferIndex = (uint32_t)arg.index;

                        info.IsVertex = true;
                        m_UniformMap[info.Name] = info;
                        
                        // resize buffer if needed
                        if (m_VertexUniformBuffer.size() < info.Offset + memb_size)
                            m_VertexUniformBuffer.resize(info.Offset + memb_size);
                    }
                }
            }
        }

        for (MTLArgument* arg in reflection.fragmentArguments) {
            if (arg.type == MTLArgumentTypeBuffer) {
                if (arg.bufferDataType == MTLDataTypeStruct) {
                    for (MTLStructMember* member in arg.bufferStructType.members) {

                        uint32_t memb_size = ShaderDataTypeSize(MetalToCrimsonDataType(member.dataType));

                        UniformInfo info;
                        info.Name = [member.name UTF8String];
                        info.Offset = (uint32_t)member.offset;
                        info.Size = memb_size;
                        info.BufferIndex = (uint32_t)arg.index;

                        info.IsVertex = false;
                        m_UniformMap[info.Name] = info;
                        
                        // resize buffer if needed
                        if (m_FragmentUniformBuffer.size() < info.Offset + memb_size) {
                            m_FragmentUniformBuffer.resize(info.Offset + memb_size);
                        }
                    }
                }
            }
        }
    }

    void MetalShader::Bind() const {
        // The encoder is needed to actually bind
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