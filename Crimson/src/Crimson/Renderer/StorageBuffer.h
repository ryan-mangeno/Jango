#pragma once
#include "Crimson/Core/Core.h"

namespace Crimson {
    class StorageBuffer {
    public:
        virtual ~StorageBuffer() = default;
        virtual void Bind(uint32_t slot) const = 0;
        virtual void SetData(const void* data, uint32_t size, uint32_t offset = 0) = 0;
        virtual void Resize(uint32_t size) = 0; // For reallocating dynamic buffers

        static Ref<StorageBuffer> Create(uint32_t size, const void* data = nullptr);
    };
}