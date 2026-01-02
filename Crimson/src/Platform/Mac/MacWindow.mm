#include "cnpch.h"
#include "MacWindow.h"

#include "Crimson/Events/ApplicationEvent.h"
#include "Crimson/Events/MouseEvent.h"
#include "Crimson/Events/KeyEvent.h"

#include "Platform/Metal/MetalContext.h"

#define GLFW_EXPOSE_NATIVE_COCOA
#include <GLFW/glfw3.h>
#include <GLFW/glfw3native.h>


#import <Foundation/Foundation.h>

namespace Crimson {

    Scope<Window> Window::Create(const WindowAttribs& attribs) {
        return MakeScope<MacWindow>(attribs);
    }

    MacWindow::MacWindow(const WindowAttribs& attribs) {
        InitWindow(attribs);
    }

    MacWindow::~MacWindow() {
        Shutdown();
    }

    void MacWindow::InitWindow(const WindowAttribs& attribs) {
        m_Data.Title = attribs.Title;
        m_Data.Width = attribs.Width;
        m_Data.Height = attribs.Height;

        // tell glfw to not create an OpenGL context
        glfwWindowHint(GLFW_CLIENT_API, GLFW_NO_API);

		CN_CORE_TRACE("Creating window {0} ({1}, {2})", attribs.Title, attribs.Width, attribs.Height);
		{
			CN_PROFILE_SCOPE("glfwCreateWindow")
        	m_Window = glfwCreateWindow((int)attribs.Width, (int)attribs.Height, m_Data.Title.c_str(), nullptr, nullptr);
		}
		CN_CORE_ASSERT(m_Window, "Window Failed to be made!");
		CN_CORE_INFO("Created Window!");


        // init metal context
        m_Context = MakeScope<MetalContext>(m_Window);
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

		glfwSetCharCallback(m_Window, [](GLFWwindow* window, unsigned int keycode)
			{
				WindowData& data = *(WindowData*)glfwGetWindowUserPointer(window);

				KeyTypedEvent event(keycode);
				data.EventCallback(event);

			});
	}

	void MacWindow::Shutdown()
	{
		CN_PROFILE_FUNCTION()
		CN_CORE_INFO("Destroying Window");

		glfwDestroyWindow(m_Window);
	}

	void MacWindow::OnUpdate()
	{
		CN_PROFILE_FUNCTION()
		glfwPollEvents();
		m_Context->SwapBuffers();
	}

	void MacWindow::SetVSync(bool enabled)
	{
		CN_PROFILE_FUNCTION()
		glfwSwapInterval(enabled);
		m_Data.VSync = enabled;
	}
}
