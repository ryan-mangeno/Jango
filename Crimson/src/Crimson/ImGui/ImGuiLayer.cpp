#include "cnpch.h"


#include "ImGuiLayer.h"
#include "Crimson/Renderer/RendererAPI.h"

#include "Platform/OpenGL/OpenGLImGuiLayer.h"
#include "Platform/Metal/MetalImGuiLayer.h"

#include <imgui.h>

namespace Crimson {

    ImGuiLayer::ImGuiLayer() : Layer("ImGuiLayer") {}
    ImGuiLayer::~ImGuiLayer() {}

    ImGuiLayer* ImGuiLayer::Create()
    {
		CN_PROFILE_FUNCTION()
		switch (RendererAPI::GetAPI())
		{
		case GraphicsAPI::OpenGL:
			return new OpenGLImGuiLayer();
		case GraphicsAPI::Metal:
			return new MetalImGuiLayer();
		case GraphicsAPI::None:
		    CN_CORE_ASSERT(false, "Unknown Platform!");
			return nullptr;
		default:
			return nullptr;
	    }
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
