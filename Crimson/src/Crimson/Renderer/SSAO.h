#pragma once

#include "Crimson/Core/Core.h"
#include "Crimson/Scene/Scene.h"
#include "Cameras/Camera.h"

namespace Crimson {

    class SSAO
    {
    public:
        virtual ~SSAO() = default;

        static Ref<SSAO> Create(int width, int height);

        virtual void SetSSAO_TextureDimension(int width, int height) = 0;
        virtual void CreateSSAOTexture(int width, int height) = 0;
        
        virtual void CaptureScene(Scene& scene, Camera& cam) = 0;

        // returns the final texture ID (void* to support both GL int and Metal id<MTLTexture>)
        virtual void* GetSSAOTextureID() = 0; 
    };
}