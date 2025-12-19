#pragma once

#include "Crimson/Renderer/GraphicsContext.h"

struct GLFWwindow;

namespace Crimson {

	class OpenGLContext : public GraphicsContext
	{
	public:
		
		// not making this scoped since its just a handle, we dont want to destroy
		// the window if this opengl context goes out of scope
		OpenGLContext(GLFWwindow* windowHandle);

		virtual void Init() override;
		virtual void SwapBuffers() override;
	private:
		GLFWwindow* m_WindowHandle;
	};
}