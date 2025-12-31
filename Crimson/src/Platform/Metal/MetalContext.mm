#include "cnpch.h"
#include "Platform/Metal/MetalContext.h"

#define GLFW_EXPOSE_NATIVE_COCOA
#include <GLFW/glfw3.h>
#include <GLFW/glfw3native.h>

#include <Metal/Metal.h>
#import <QuartzCore/CAMetalLayer.h>

namespace Crimson {

    MetalContext::MetalContext(GLFWwindow* windowHandle)
        : m_WindowHandle(windowHandle)
    {
        CN_CORE_ASSERT(windowHandle, "Window Handle is null!")
    }

    void MetalContext::Init()
    {
        CN_PROFILE_FUNCTION()

        // create the GPU Device
        // equivalent to "creating a context" in OpenGL
        id<MTLDevice> device = MTLCreateSystemDefaultDevice();
        CN_CORE_ASSERT(device, "Metal is not supported on this system!");

        //  get native window
        NSWindow* nswin = glfwGetCocoaWindow(m_WindowHandle);
        
        // create and attach metal layer
        // This replaces the "Default Framebuffer" concept in OpenGL
        CAMetalLayer* layer = [CAMetalLayer layer];
        layer.device = device;
        layer.pixelFormat = MTLPixelFormatBGRA8Unorm; // standard color fomrat
        layer.framebufferOnly = YES; // optimization: true if you dont read pixels back
        
        // attach layer to the Cocoa window view
        nswin.contentView.layer = layer;
        nswin.contentView.wantsLayer = YES;

        CN_CORE_INFO("Metal Context Initialized");
        CN_CORE_INFO("  GPU: {0}", [device.name UTF8String]);
    }

    void MetalContext::SwapBuffers()
    {
        // Metal does not use "SwapBuffers" in the Context
        // In OpenGL, glfwSwapBuffers() flips the window
        // In Metal, the "Flip" happens when you call [commandBuffer presentDrawable]
        // inside your Renderer, so this function stays empty here
    }
}