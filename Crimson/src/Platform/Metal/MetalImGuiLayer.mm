#include "cnpch.h"
#include "MetalImGuiLayer.h"
#include "Crimson/Core/Application.h"
#include "Platform/Metal/MetalRendererAPI.h"

#include <imgui.h>
#include <backends/imgui_impl_glfw.h>
#include <backends/imgui_impl_metal.h>
#include "ImGuizmo.h"

#import <Metal/Metal.h>
#import <QuartzCore/QuartzCore.h>
#include <GLFW/glfw3.h>

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

        // rounding fix for Mac Viewports
        if (io.ConfigFlags & ImGuiConfigFlags_ViewportsEnable) {
            ImGui::GetStyle().WindowRounding = 0.0f;
            ImGui::GetStyle().Colors[ImGuiCol_WindowBg].w = 1.0f;
        }

        Application& app = Application::Get();
        GLFWwindow* window = static_cast<GLFWwindow*>(app.GetWindow().GetNativeWindow());

        ImGui_ImplGlfw_InitForOpenGL(window, true);

        id<MTLDevice> device = (__bridge id<MTLDevice>)MetalRendererAPI::GetDevice();
        ImGui_ImplMetal_Init(device);
    }

    void MetalImGuiLayer::OnDetach()
    {
        ImGui_ImplMetal_Shutdown();
        ImGui_ImplGlfw_Shutdown();
        ImGui::DestroyContext();
    }

    void MetalImGuiLayer::Begin()
    {
        MTLRenderPassDescriptor* renderPassDescriptor = [MTLRenderPassDescriptor renderPassDescriptor];
        
        ImGui_ImplMetal_NewFrame(renderPassDescriptor);
        ImGui_ImplGlfw_NewFrame();
        ImGui::NewFrame();
        ImGuizmo::BeginFrame();
    }

    void MetalImGuiLayer::End()
    {
        ImGuiIO& io = ImGui::GetIO();
        Application& app = Application::Get();
        io.DisplaySize = ImVec2((float)app.GetWindow().GetWidth(), (float)app.GetWindow().GetHeight());

        ImGui::Render();

        id<MTLRenderCommandEncoder> encoder = (__bridge id<MTLRenderCommandEncoder>)MetalRendererAPI::GetCurrentEncoder();
        
        // get the CommandBuffer from api
        id<MTLCommandBuffer> cmdBuffer = (__bridge id<MTLCommandBuffer>)MetalRendererAPI::GetCurrentCommandBuffer();

        if (encoder && cmdBuffer)
        {
            [encoder pushDebugGroup:@"Dear ImGui"];
            
            // pass the separate command buffer
            ImGui_ImplMetal_RenderDrawData(ImGui::GetDrawData(), cmdBuffer, encoder);
            
            [encoder popDebugGroup];
        }

        if (io.ConfigFlags & ImGuiConfigFlags_ViewportsEnable)
        {
            ImGui::UpdatePlatformWindows();
            ImGui::RenderPlatformWindowsDefault();
        }
    }
}