#include "cnpch.h"
#include "ImGuiLayer.h"

#include "imgui.h"
#include "backends/imgui_impl_glfw.h"
#include "backends/imgui_impl_opengl3.h"
#include "Crimson/Core/Application.h"
#include "ImGuizmo.h"

// temp
#include <GLFW/glfw3.h>
#include <glad/glad.h>
namespace Crimson {

	#define BIND_FUNC(x) std::bind(&ImGuiLayer::x,this,std::placeholders::_1)


	ImFont* ImGuiLayer::s_Font = nullptr;

	ImGuiLayer::ImGuiLayer()
		:Layer("ImGuiLayer")
	{
	}


	ImGuiLayer::~ImGuiLayer()
	{
	}

	void ImGuiLayer::Begin()
	{

		CN_PROFILE_FUNCTION()


		ImGui_ImplOpenGL3_NewFrame();
		ImGui_ImplGlfw_NewFrame();
		ImGui::NewFrame();
		ImGuizmo::BeginFrame();
	}

	void ImGuiLayer::End()
	{
		CN_PROFILE_FUNCTION()


		ImGuiIO& io = ImGui::GetIO();
		Application& app = Application::Get();
		io.DisplaySize = ImVec2(float(app.GetWindow().GetWidth()), float(app.GetWindow().GetHeight()));

		ImGui::Render();
		ImGui_ImplOpenGL3_RenderDrawData(ImGui::GetDrawData());

		if (io.ConfigFlags && ImGuiConfigFlags_ViewportsEnable)
		{
			GLFWwindow* backup_current_context = glfwGetCurrentContext();
			ImGui::UpdatePlatformWindows();
			ImGui::RenderPlatformWindowsDefault();
			glfwMakeContextCurrent(backup_current_context);
		}
	}

	void ImGuiLayer::OnAttach()
	{
		IMGUI_CHECKVERSION();
		ImGui::CreateContext();
		ImGuiIO& io = ImGui::GetIO(); (void)io;
		io.ConfigFlags |= ImGuiConfigFlags_NavEnableKeyboard;       // Enable Keyboard Controls
		io.ConfigFlags |= ImGuiConfigFlags_DockingEnable;           // Enable Docking
		io.ConfigFlags |= ImGuiConfigFlags_ViewportsEnable;         // Enable Multi-Viewport / Platform Windows

		io.FontDefault = io.Fonts->AddFontFromFileTTF("Crimson_Editor/Assets/Font/OpenSans-Bold.ttf", 18.0f);
		s_Font = io.Fonts->AddFontFromFileTTF("Crimson_Editor/Assets/Font/OpenSans-ExtraBold.ttf", 20.0f);

		ImGui::StyleColorsDark();

		ImGuiStyle& style = ImGui::GetStyle();
		if (io.ConfigFlags & ImGuiConfigFlags_ViewportsEnable)
		{
			style.WindowRounding = 0.0f;
			style.Colors[ImGuiCol_WindowBg].w = 1.0f;
		}

		SetDarkThemeColors();

		GLFWwindow* window = (GLFWwindow*)Application::Get().GetWindow().GetNativeWindow();
		
		// Setup Platform/Renderer backends
		ImGui_ImplGlfw_InitForOpenGL(window, true);

		ImGui_ImplOpenGL3_Init("#version 410");

	}

	void ImGuiLayer::OnDetach()
	{
		ImGui_ImplGlfw_Shutdown();
		ImGui_ImplOpenGL3_Shutdown();
		ImGui::DestroyContext();
	}

	void ImGuiLayer::OnImGuiRender()
	{
	}

	void ImGuiLayer::SetDarkThemeColors()
	{
		auto& colors = ImGui::GetStyle().Colors;
		colors[ImGuiCol_WindowBg] = { 0.1f ,0.105f ,0.1f ,1.0f };

		colors[ImGuiCol_Header] = { 0.2f ,0.205f ,0.21f ,1.0f };
		colors[ImGuiCol_HeaderHovered] = { 0.3f ,0.305f ,0.3f ,1.0f };
		colors[ImGuiCol_HeaderActive] = { 0.1f ,0.105f ,0.1f ,1.0f };

		colors[ImGuiCol_Button] = { 0.2f ,0.205f ,0.21f ,1.0f };
		colors[ImGuiCol_ButtonHovered] = { 0.4f ,0.405f ,0.4f ,1.0f };
		colors[ImGuiCol_ButtonActive] = { 0.1f ,0.105f ,0.1f ,1.0f };

		colors[ImGuiCol_FrameBg] = { 0.2f ,0.205f ,0.21f ,1.0f };
		colors[ImGuiCol_FrameBgHovered] = { 0.3f ,0.305f ,0.3f ,1.0f };
		colors[ImGuiCol_FrameBgActive] = { 0.1f ,0.105f ,0.1f ,1.0f };

		colors[ImGuiCol_Tab] = { 0.25f ,0.2505f ,0.251f ,1.0f };
		colors[ImGuiCol_TabHovered] = { 0.78f ,0.7805f ,0.78f ,1.0f };
		colors[ImGuiCol_TabActive] = { 0.681f ,0.6805f ,0.681f ,1.0f };
		colors[ImGuiCol_TabUnfocused] = { 0.35f ,0.3505f ,0.351f ,1.0f };
		colors[ImGuiCol_TabUnfocusedActive] = { 0.5f,0.505f,0.51f,1.0f };

		colors[ImGuiCol_TitleBg] = { 0.15f,0.1505f,0.15f,1.0f };
		colors[ImGuiCol_TitleBgActive] = { 0.15f,0.1505f,0.15f,1.0f };
		colors[ImGuiCol_TitleBgCollapsed] = { 0.95f,0.1505f,0.951f,1.0f };
	}


}