#pragma once

#include "Crimson/Core/Layer.h"
#include "Crimson/Events/ApplicationEvent.h"
#include "Crimson/Events/KeyEvent.h"
#include "Crimson/Events/MouseEvent.h"

namespace Crimson {

    class ImGuiLayer : public Layer
    {
    public:
        ImGuiLayer();
        virtual ~ImGuiLayer();

        virtual void OnAttach() override = 0;
        virtual void OnDetach() override = 0;
        virtual void OnImGuiRender() override = 0;

        virtual void Begin() = 0;
        virtual void End() = 0;

        void SetDarkThemeColors();
        
		static ImGuiLayer* Create();

    protected:
        float m_Time = 0.0f;
    };
}