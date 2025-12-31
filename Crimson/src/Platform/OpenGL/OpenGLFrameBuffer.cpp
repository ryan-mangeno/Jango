#include "cnpch.h"
#include "OpenGLFrameBuffer.h"
#include "glad/glad.h"
#include "Crimson/Core/Log.h"

namespace Crimson {
    OpenGLFrameBuffer::OpenGLFrameBuffer(const FrameBufferSpecification& spec)
    {
        invalidate(spec);
    }
    OpenGLFrameBuffer::~OpenGLFrameBuffer()
    {
        glDeleteFramebuffers(1, &m_RenderID);
        glDeleteTextures(1, &m_SceneTexture);
        glDeleteTextures(1, &m_DepthTexture);
    }
    void OpenGLFrameBuffer::Bind()
    {
        glBindFramebuffer(GL_DRAW_FRAMEBUFFER, m_RenderID);
    }
    void OpenGLFrameBuffer::UnBind()
    {
        glBindFramebuffer(GL_DRAW_FRAMEBUFFER, 0);
    }
    void OpenGLFrameBuffer::Resize(uint32_t width, uint32_t height)
    {
        Specification.viewport = { width, height };
        invalidate(Specification);
        glViewport(0, 0, width, height);
    }
    void OpenGLFrameBuffer::ClearFrameBuffer()
    {
        const float clearColor[4] = { 0.0f, 0.0f, 0.0f, 1.0f };
        glClearBufferfv(GL_COLOR, 0, clearColor);
        glFlush();
    }
    void OpenGLFrameBuffer::BindFramebufferTexture(int slot)
    {
        glBindTextureUnit(slot, m_SceneTexture);
    }
    void OpenGLFrameBuffer::BindFramebufferDepthTexture(int slot)
    {
        glBindTextureUnit(slot, m_DepthTexture);
    }
    void OpenGLFrameBuffer::invalidate(const FrameBufferSpecification& spec)
    {


        CN_PROFILE_FUNCTION()

        if (m_RenderID)
        {
            glDeleteFramebuffers(1, &m_RenderID);
            glDeleteTextures(1, &m_SceneTexture);
            glDeleteTextures(1, &m_DepthTexture);
        }

        Specification = spec;

        glGenFramebuffers(1, &m_RenderID);
        glBindFramebuffer(GL_FRAMEBUFFER, m_RenderID);

        glGenTextures(1, &m_SceneTexture);
        glBindTexture(GL_TEXTURE_2D, m_SceneTexture);
        glTexImage2D(GL_TEXTURE_2D, 0, GL_RGB8, spec.viewport.x, spec.viewport.y, 0, GL_RGB, GL_UNSIGNED_BYTE, nullptr);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
        glBindTexture(GL_TEXTURE_2D, 0);

        glFramebufferTexture2D(GL_DRAW_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, m_SceneTexture, 0);
        const GLenum buffers[1] = { GL_COLOR_ATTACHMENT0 };
        glDrawBuffers(1, buffers);

        glGenTextures(1, &m_DepthTexture);
        glBindTexture(GL_TEXTURE_2D, m_DepthTexture);
        glTexImage2D(GL_TEXTURE_2D, 0, GL_DEPTH_COMPONENT32, spec.viewport.x, spec.viewport.y, 0, GL_DEPTH_COMPONENT, GL_FLOAT, nullptr);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
        glBindTexture(GL_TEXTURE_2D, 0);

        glFramebufferTexture2D(GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT, GL_TEXTURE_2D, m_DepthTexture, 0);


        if (glCheckFramebufferStatus(GL_FRAMEBUFFER) != GL_FRAMEBUFFER_COMPLETE)
            CN_CORE_ERROR("Scene FrameBuffer Failed")

        glBindFramebuffer(GL_FRAMEBUFFER, 0);
    }
}