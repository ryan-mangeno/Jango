#pragma once
#include "Crimson/ImGui/ImGuiLayer.h"

namespace Crimson {
    class MetalImGuiLayer : public ImGuiLayer {
    public:
        MetalImGuiLayer();
        ~MetalImGuiLayer();
        virtual void OnAttach() override;
        virtual void OnDetach() override;
        virtual void OnImGuiRender() override {}
        virtual void Begin() override;
        virtual void End() override;
    };
}