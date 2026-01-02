#include "cnpch.h"
#include "OpenGLFrameBuffer.h"
#include "glad/glad.h"
#include "Crimson/Core/Log.h"
#include "Platform/OpenGL/OpenGLTexture2D.h" 

namespace Crimson {

    OpenGLFrameBuffer::OpenGLFrameBuffer(const FrameBufferSpecification& spec)
        : m_Specification(spec)
    {
        Invalidate();
    }

    OpenGLFrameBuffer::~OpenGLFrameBuffer()
    {
        glDeleteFramebuffers(1, &m_RendererID);
        glDeleteTextures(m_ColorAttachments.size(), m_ColorAttachments.data());
        glDeleteTextures(1, &m_DepthAttachment);
    }

    void OpenGLFrameBuffer::Invalidate()
    {
        CN_PROFILE_FUNCTION()

        if (m_RendererID)
        {
            glDeleteFramebuffers(1, &m_RendererID);
            glDeleteTextures(m_ColorAttachments.size(), m_ColorAttachments.data());
            glDeleteTextures(1, &m_DepthAttachment);
            
            m_ColorAttachments.clear();
            m_DepthAttachment = 0;
        }

        glCreateFramebuffers(1, &m_RendererID);
        glBindFramebuffer(GL_FRAMEBUFFER, m_RendererID);

        // Color Attachment
        // Note: We are hardcoding RGB16F here because CubeMap code needs HDR
        // In the future, use m_Specification.Attachments to pick the format dynamically
        uint32_t colorAttachment;
        glCreateTextures(GL_TEXTURE_2D, 1, &colorAttachment);
        glBindTexture(GL_TEXTURE_2D, colorAttachment);
        
        glTexImage2D(GL_TEXTURE_2D, 0, GL_RGB16F, m_Specification.Width, m_Specification.Height, 0, GL_RGB, GL_FLOAT, nullptr);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
        
        glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, colorAttachment, 0);
        
        m_ColorAttachments.push_back(colorAttachment); 

        // Create Depth Attachment
        glCreateTextures(GL_TEXTURE_2D, 1, &m_DepthAttachment);
        glBindTexture(GL_TEXTURE_2D, m_DepthAttachment);
        glTexImage2D(GL_TEXTURE_2D, 0, GL_DEPTH_COMPONENT32, m_Specification.Width, m_Specification.Height, 0, GL_DEPTH_COMPONENT, GL_FLOAT, nullptr);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
        glFramebufferTexture2D(GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT, GL_TEXTURE_2D, m_DepthAttachment, 0);

        if (glCheckFramebufferStatus(GL_FRAMEBUFFER) != GL_FRAMEBUFFER_COMPLETE)
            CN_CORE_ERROR("Framebuffer is incomplete!");

        glBindFramebuffer(GL_FRAMEBUFFER, 0);
    }

    void OpenGLFrameBuffer::Bind()
    {
        glBindFramebuffer(GL_FRAMEBUFFER, m_RendererID);
        glViewport(0, 0, m_Specification.Width, m_Specification.Height);
    }

    void OpenGLFrameBuffer::UnBind()
    {
        glBindFramebuffer(GL_FRAMEBUFFER, 0);
    }

    void OpenGLFrameBuffer::Resize(uint32_t width, uint32_t height)
    {
        if (width == 0 || height == 0)
        {
            CN_CORE_WARN("Attempted to resize framebuffer to {0}, {1}", width, height);
            return;
        }
        m_Specification.Width = width;
        m_Specification.Height = height;
        
        Invalidate();
    }

    void OpenGLFrameBuffer::SetAttachment(Ref<Texture2D> texture, uint32_t attachmentIndex)
    {
        uint32_t id = texture->GetRendererID();
        glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0 + attachmentIndex, GL_TEXTURE_2D, id, 0);
    }

    void OpenGLFrameBuffer::SetAttachment(Ref<TextureCube> texture, uint32_t attachmentIndex, uint32_t faceIndex, uint32_t mipLevel)
    {
        std::shared_ptr<OpenGLTextureCube> glTexture = std::dynamic_pointer_cast<OpenGLTextureCube>(texture);
        if (glTexture)
        {
            uint32_t id = glTexture->GetRendererID();
            glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0 + attachmentIndex, GL_TEXTURE_CUBE_MAP_POSITIVE_X + faceIndex, id, mipLevel);
        }
    }
    
    void OpenGLFrameBuffer::ClearAttachment(uint32_t attachmentIndex, int value)
    {
        if (attachmentIndex < m_ColorAttachments.size())
        {
            glClearTexImage(m_ColorAttachments[attachmentIndex], 0, GL_RGBA, GL_INT, &value);
        }
    }
}