#pragma once

#include "Crimson/Core/Log.h"

namespace Crimson {

#ifdef CN_PLATFORM_MACOS
    using PlatformGPUHandle = void*;
#else
    using PlatformGPUHandle = uint32_t;
#endif



    class GPUHandle {
    public:
        GPUHandle() = default;

        explicit GPUHandle(uint32_t gl)
            :   m_Data(static_cast<uintptr_t>(gl)) {}

        explicit GPUHandle(void* metal)
            :   m_Data(reinterpret_cast<uintptr_t>(metal)) {}
        
        inline PlatformGPUHandle ToPlatform() const {
        #ifdef CN_PLATFORM_MACOS
            return ToMetal();
        #elif CN_PLATFORM_WINDOWS
            return ToGL();
        #else 
            CN_CORE_ERROR("Error: GPU Handle not Supported!")
            return 0;
        #endif
        }

        explicit operator uint32_t() const { return ToGL(); }
        explicit operator void*() const { return ToMetal(); }
    
    private:
        uint32_t ToGL() const {
            return static_cast<uint32_t>(m_Data);
        }
        void* ToMetal() const {
            return reinterpret_cast<void*>(m_Data);
        }

    private:
        uintptr_t   m_Data = 0;
    };



}
