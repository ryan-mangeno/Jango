#include "cnpch.h"
#include "Application.h"
#include "Input.h"

#include "Crimson/Events/ApplicationEvent.h"
#include "Crimson/Events/KeyEvent.h"
#include "Crimson/Events/MouseEvent.h"
#include "Subsystems.h"

#include "Crimson/Renderer/Renderer.h"

#include "Crimson/Core/TimeStep.h"

#include "Crimson/Renderer/OrthographicCamera.h"

#include "Crimson/Renderer/util/Time.h"


#define BIND_EVENT_FN(x) std::bind(&Application::x,this,std::placeholders::_1)


namespace Crimson {

	// deltaTime and App are both singletons, there is only going to be one instance of both

	Application* Application::s_Instance;
	TimeStep Application::s_TimeStep(0.0);

	Application::Application()
	{

		CN_PROFILE_FUNCTION()
 
 		CN_CORE_ASSERT(s_Instance == nullptr, "Already Created Application!");
		s_Instance = this;
		

		m_Window = Scope<Window>(Window::Create()); // window is a unique ptr not shared since it is tied to the application instance not the program
		m_Window->SetEventCallback(BIND_EVENT_FN(OnEvent));
		m_Window->SetVSync(false); // vsync defaults to true for opengl setup, just setting to false for testing

		Renderer::Init(); // this sets the renderer-api in reality ... does not initialize the 2d and 3d renderer

		m_ImGuiLayer = ImGuiLayer::Create(); // layers get deleted in layer stack destructor
		PushOverlay(m_ImGuiLayer);
	}

	Application::~Application()
	{
	} 


	void Application::OnEvent(Event& e)
	{
		CN_PROFILE_FUNCTION()

			EventDispatcher dispatcher(e);

		// even though we dispatch starting from top layer, on windows closed we dont check other layers
		// we simply terminate
		dispatcher.Dispatch<WindowCloseEvent>(BIND_EVENT_FN(OnWindowClosed));
		dispatcher.Dispatch<WindowResizeEvent>(BIND_EVENT_FN(OnWindowResize));

		//CN_CORE_TRACE(e.ToString());

		// going backwards since if an overlay with some button handles event
		// we are done, we dont propogate
		for (auto it = m_LayerStack.end(); it != m_LayerStack.begin();)
		{
			// we need to decrement first since it points one past pos
			(*(--it))->OnEvent(e);
			if (e.GetHandled())
				break;
		}
	}

	void Application::PushLayer(Layer* layer)
	{
		CN_CORE_INFO("Layer {0}, Pushed onto LayerStack", layer->GetName());
		m_LayerStack.PushLayer(layer);
		layer->OnAttach();
	}

	void Application::PushOverlay(Layer* Overlay)
	{
		CN_CORE_INFO("Overlay {0}, Pushed onto LayerStack", Overlay->GetName());
		m_LayerStack.PushOverlay(Overlay);
		Overlay->OnAttach();
	}

	bool Application::OnWindowClosed(WindowCloseEvent& EventClose)
	{
		m_Running = false;
		return true;
	}

	bool Application::OnWindowResize(WindowResizeEvent& e)
	{
		CN_PROFILE_FUNCTION()

		if (e.GetWidth() == 0 || e.GetHeight() == 0){
			m_Minimized = true;
			return false;
		}

		Renderer::WindowResize(e.GetWidth(), e.GetHeight());
		m_Minimized = false;
		return false;
	}


	void Application::Run()
	{
		while (m_Running) 
		{
			float time = GetTime(); 
			s_TimeStep = time - m_LastFrameTime;
			m_LastFrameTime = time;
			if (!m_Minimized)
			{
				{
					CN_PROFILE_SCOPE("Layer OnUpdates")
					// we can use range based for loop because we implimented begin and end
					for (const auto& layer : m_LayerStack)
					{
						layer->OnUpdate(s_TimeStep);
					}
				}
				m_ImGuiLayer->Begin();
				{
					CN_PROFILE_SCOPE("LayerStack OnImGuiRender")
					for (const auto& layer : m_LayerStack)
					{
						layer->OnImGuiRender();
					}
				}
				m_ImGuiLayer->End();
			}
			m_Window->OnUpdate();
			}
		}
	}


