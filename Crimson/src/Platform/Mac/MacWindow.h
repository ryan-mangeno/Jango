#pragma once
#include "Crimson/Core/Window.h"
#include "Crimson/Renderer/GraphicsContext.h"
#include <GLFW/glfw3.h>

namespace Crimson {
    class MacWindow : public Window {
    public:
        MacWindow(const WindowAttribs& attribs);
        virtual ~MacWindow();

        void OnUpdate() override;

        inline uint32_t GetWidth() const override { return m_Data.Width; }
        inline uint32_t GetHeight() const override { return m_Data.Height; }

        inline void SetEventCallback(const EventCallbackFn& callback) override { m_Data.EventCallback = callback; }
        void SetVSync(bool enabled) override;
        bool IsVSync() const override { return m_Data.VSync; }

        inline virtual void* GetNativeWindow() const override { return m_Window; }
    private:
        virtual void InitWindow(const WindowAttribs& attribs);
        virtual void Shutdown();
    private:
        GLFWwindow* m_Window;
        Scope<GraphicsContext> m_Context;

        struct WindowData {
            std::string Title;
            uint32_t Width, Height;
            bool VSync;
            EventCallbackFn EventCallback;
        };

        WindowData m_Data;
    };
}