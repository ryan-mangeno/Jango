#pragma once
#include "Crimson/Renderer/Antialiasing.h"

namespace Crimson
{
    class MetalAntialiasing : public Antialiasing
    {
    public:
        MetalAntialiasing(int width, int height);
        ~MetalAntialiasing();
        
        void Init(int width, int height);
        void Update() override;
        void RenderQuad(); // kept for API compatibility, but empty implementation

    private:
        void* m_MetalData = nullptr; 

        int m_Width, m_Height;
        int m_num_frame = 0;
    };
}