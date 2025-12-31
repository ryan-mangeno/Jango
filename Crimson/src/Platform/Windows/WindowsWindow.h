#pragma once


#include "Crimson/Core/Window.h"
#include "Crimson/Renderer/GraphicsContext.h"

#include <GLFW/glfw3.h>

namespace Crimson {

	class WindowsWindow : public Window
	{

	public:

		WindowsWindow(const WindowAttribs& attribs);
		virtual ~WindowsWindow();

		void OnUpdate() override;

		inline uint32_t GetWidth() const override { return m_Data.Width; }
		inline uint32_t GetHeight() const override { return m_Data.Height; }

		// Windows attributes
		inline void SetEventCallback(const EventCallbackFn& callback) override { m_Data.EventCallback = callback; }
		void SetVSync(bool enabled) override;
		inline bool IsVSync() const override { return m_Data.VSync; }

		// even though these are simply called in destructor and constructor 
		// I want to be able to have explicit functions for naming and seperation
		virtual void InitWindow(const WindowAttribs& attribs);
		virtual void Shutdown();

		inline virtual void* GetNativeWindow() const override { return static_cast<void*>(m_Window); }


	private:

		GLFWwindow* m_Window;

		Scope<GraphicsContext> m_Context;

		struct WindowData
		{
			std::string Title;
			uint32_t Width;
			uint32_t Height;
			bool VSync;

			EventCallbackFn EventCallback;
		};

		WindowData m_Data;
	};


}