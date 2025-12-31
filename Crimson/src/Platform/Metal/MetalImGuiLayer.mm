#include "cnpch.h"

#include "MetalImGuiLayer.h"
#include "Crimson/Core/Application.h"

#include <imgui.h>
#include <backends/imgui_impl_glfw.h>
#include <backends/imgui_impl_opengl3.h>
#include "ImGuizmo.h"

#include <GLFW/glfw3.h>
#include <glad/glad.h>

namespace Crimson {

    MetalImGuiLayer::MetalImGuiLayer() {}
    MetalImGuiLayer::~MetalImGuiLayer() {}

    void MetalImGuiLayer::OnAttach()
    {
        IMGUI_CHECKVERSION();
        ImGui::CreateContext();
        ImGuiIO& io = ImGui::GetIO(); (void)io;
        io.ConfigFlags |= ImGuiConfigFlags_NavEnableKeyboard;
        io.ConfigFlags |= ImGuiConfigFlags_DockingEnable;
        io.ConfigFlags |= ImGuiConfigFlags_ViewportsEnable;

        ImGui::StyleColorsDark();
        SetDarkThemeColors();

        Application& app = Application::Get();
        GLFWwindow* window = static_cast<GLFWwindow*>(app.GetWindow().GetNativeWindow());
#ifdef CN_PLATFORM_WINDOWS // temp
        ImGui_ImplGlfw_InitForMetal(window, true);
        ImGui_ImplMetal3_Init("#version 410");
#endif
    }

    void MetalImGuiLayer::OnDetach()
    {
#ifdef CN_PLATFORM_WINDOWS // temp
        ImGui_ImplMetal3_Shutdown();
        ImGui_ImplGlfw_Shutdown();
        ImGui::DestroyContext();
#endif
    }

    void MetalImGuiLayer::Begin()
    {
#ifdef CN_PLATFORM_WINDOWS // temp
        ImGui_ImplMetal3_NewFrame();
        ImGui_ImplGlfw_NewFrame();
        ImGui::NewFrame();
        ImGuizmo::BeginFrame();
#endif
    }

    void MetalImGuiLayer::End()
    {
        ImGuiIO& io = ImGui::GetIO();
        Application& app = Application::Get();
        io.DisplaySize = ImVec2((float)app.GetWindow().GetWidth(), (float)app.GetWindow().GetHeight());

        ImGui::Render();
#ifdef CN_PLATFORM_WINDOWS // temp
        ImGui_ImplMetal3_RenderDrawData(ImGui::GetDrawData());
#endif

        if (io.ConfigFlags & ImGuiConfigFlags_ViewportsEnable)
        {
            GLFWwindow* backup_current_context = glfwGetCurrentContext();
#ifdef CN_PLATFORM_WINDOWS // temp
            ImGui::UpdatePlatformWindows();
            ImGui::RenderPlatformWindowsDefault();
#endif
            glfwMakeContextCurrent(backup_current_context);
        }
    }
}