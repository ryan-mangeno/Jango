#pragma once
#include "Core.h"
#include "Window.h"
#include "Crimson/Events/ApplicationEvent.h"
#include "LayerStack.h"
#include "Crimson/ImGui/ImGuiLayer.h"
#include "Crimson/Renderer/Shader.h"
#include "Crimson/Renderer/Buffer.h"
#include "Crimson/Renderer/OrthographicCamera.h"
#include "KeyCodes.h"
#include "Crimson/Core/TimeStep.h"

namespace Crimson {
	class Application { 
	public:
		Application();
		virtual ~Application();

		void Run();
		void OnEvent(Event& e);

		void PushLayer(Layer* layer);
		void PushOverlay(Layer* Overlay);

		inline Window& GetWindow() { return *m_Window; }
		static inline Application& Get() { return *s_Instance; }
		inline ImGuiLayer* GetImGuiLayer() { return m_ImGuiLayer; }


	public:
		glm::vec3 v3;
		float v = 0.f;
		float r = 0.f;


	private:

		bool m_Running = true;
		bool m_Minimized = false;

		std::unique_ptr<Window> m_Window;
		bool OnWindowClosed(WindowCloseEvent&);
		bool OnWindowResize(WindowResizeEvent& e);

		LayerStack m_LayerStack;
		ImGuiLayer* m_ImGuiLayer;

		static Application* s_Instance;
		static TimeStep s_TimeStep;

		float m_LastFrameTime;
	};

	//define in client
	Application* CreateApplication();

}


