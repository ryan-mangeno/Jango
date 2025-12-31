#include "cnpch.h"
#include "WindowsWindow.h"

#include "Crimson/Events/ApplicationEvent.h"
#include "Crimson/Events/MouseEvent.h"
#include "Crimson/Events/KeyEvent.h"
#include "Crimson/Core/Subsystems.h"

#include "Platform/OpenGL/OpenGLContext.h"



namespace Crimson {

	Scope<Window> Window::Create(const WindowAttribs& attribs)
	{
		return  MakeScope<WindowsWindow>(attribs);
	}

	WindowsWindow::WindowsWindow(const WindowAttribs& attribs)
	{
		CN_PROFILE_FUNCTION()
		// currently calling inside of constructor, we might want to call
		// other things during construction of windows
		// want to keep them all seperate
		Subsystems::InitGL();
		InitWindow(attribs);
	}

	WindowsWindow::~WindowsWindow()
	{
		Shutdown();
	}

	

	void WindowsWindow::InitWindow(const WindowAttribs& attribs)
	{
		m_Data.Title = attribs.Title;
		m_Data.Width = attribs.Width;
		m_Data.Height = attribs.Height;

		CN_CORE_INFO("Creating Window {0} ({1}, {2})", attribs.Title, attribs.Width, attribs.Height);

		// gl intialized before we init attribs
		{
			CN_PROFILE_SCOPE("glfwCreateWindow")
			m_Window = glfwCreateWindow((int)attribs.Width, (int)attribs.Height, m_Data.Title.c_str(), nullptr, nullptr);
		}
		CN_CORE_ASSERT(m_Window, "Window Failed to be made!");

		m_Context = MakeScope<OpenGLContext>(m_Window);
		m_Context->Init();
		
		

		glfwSetWindowUserPointer(m_Window, &m_Data);
		SetVSync(true);

		glfwSetWindowSizeCallback(m_Window, [](GLFWwindow* window, int width, int height)
			{
				WindowData& data = *(WindowData*)glfwGetWindowUserPointer(window);
				data.Width = width;
				data.Height = height;

				WindowResizeEvent event(width, height);
				data.EventCallback(event);

			});

		glfwSetWindowCloseCallback(m_Window, [](GLFWwindow* window)
			{
				WindowData& data = *(WindowData*)glfwGetWindowUserPointer(window);
				data.Width = 0;
				data.Height = 0;
				
				WindowCloseEvent event;
				data.EventCallback(event);

			});

		glfwSetKeyCallback(m_Window, [](GLFWwindow* window, int key, int scancode, int action, int mods)
			{
				WindowData& data = *(WindowData*)glfwGetWindowUserPointer(window);
				
				switch (action)
				{

					case GLFW_PRESS:
					{
						KeyPressedEvent event(key, 0);
						data.EventCallback(event);
						break;
					}
					case GLFW_RELEASE:
					{
						KeyReleasedEvent event(key);
						data.EventCallback(event);
						break;
					}
					case GLFW_REPEAT:
					{
						KeyPressedEvent event(key, 1);
						data.EventCallback(event);
						break;
					}

				}
				

			});

		glfwSetMouseButtonCallback(m_Window, [](GLFWwindow* window, int button, int action, int mods)
			{
				WindowData& data = *(WindowData*)glfwGetWindowUserPointer(window);

				switch (action)
				{

					case GLFW_PRESS:
					{
						MouseButtonPressedEvent event(button);
						data.EventCallback(event);
						break;
					}
					case GLFW_RELEASE:
					{
						MouseButtonReleasedEvent event(button);
						data.EventCallback(event);
						break;
					}

				}

			});

		glfwSetScrollCallback(m_Window, [](GLFWwindow* window, double xOffset, double yOffset)
			{
				WindowData& data = *(WindowData*)glfwGetWindowUserPointer(window);

				MouseScrolledEvent event((float)xOffset, (float)yOffset);
				data.EventCallback(event);

			});

		glfwSetCursorPosCallback(m_Window, [](GLFWwindow* window, double xPos, double yPos)
			{
				WindowData& data = *(WindowData*)glfwGetWindowUserPointer(window);

				MouseMovedEvent event((float)xPos, (float)yPos);
				data.EventCallback(event);

			});

		glfwSetCharCallback(m_Window, [](GLFWwindow* window, uint32_t keycode)
			{
				WindowData& data = *(WindowData*)glfwGetWindowUserPointer(window);

				KeyTypedEvent event(keycode);
				data.EventCallback(event);

			});
	}

	void WindowsWindow::Shutdown()
	{
		CN_PROFILE_FUNCTION()
		CN_CORE_INFO("Destroying Window");

		// calls glfwDestroyWindow
		glfwDestroyWindow(m_Window);
	}

	void WindowsWindow::OnUpdate()
	{
		CN_PROFILE_FUNCTION()
		// proccessing callbacks 
		glfwPollEvents();
		m_Context->SwapBuffers();
	}

	void WindowsWindow::SetVSync(bool enabled)
	{
		CN_PROFILE_FUNCTION()
		glfwSwapInterval(enabled);
		m_Data.VSync = enabled;
	}
}
