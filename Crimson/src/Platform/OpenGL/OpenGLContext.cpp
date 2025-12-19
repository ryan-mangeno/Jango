#include "cnpch.h"
#include "OpenGLContext.h"

#include <GLFW/glfw3.h>
#include <glad/glad.h>

namespace Crimson {
	OpenGLContext::OpenGLContext(GLFWwindow* windowHandle)
		: m_WindowHandle(windowHandle)
	{
		CN_CORE_ASSERT(windowHandle, "Window Handle is null!")
	}

	void OpenGLContext::Init()
	{

		CN_PROFILE_FUNCTION()

		glfwMakeContextCurrent(m_WindowHandle);

		// init glad after creating context
		int status = gladLoadGLLoader((GLADloadproc)glfwGetProcAddress);
		CN_CORE_ASSERT(status, "Failed to initialize GLAD!");

		CN_CORE_INFO("	Vendor: {0}", (char*)glGetString(GL_VENDOR));
		CN_CORE_INFO("	Renderer: {0}", (char*)glGetString(GL_RENDERER));
		CN_CORE_INFO("	Version: {0}", (char*)glGetString(GL_VERSION));
	}

	void OpenGLContext::SwapBuffers()
	{
		glfwSwapBuffers(m_WindowHandle);
	}
}

