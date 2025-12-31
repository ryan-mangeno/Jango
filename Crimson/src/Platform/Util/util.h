#pragma once

#ifdef CN_PLATFORM_WINDOWS

    #define jg_print_s(...) printf_s(__VA_ARGS__)
    #define jg_strcpy_s(...) strcpy_s(__VA_ARGS_)

#elif defined(CN_PLATFORM_MACOS)

    #include <stdio.h>
    #include <string.h>
    #include <stdarg.h>
    
    inline void jg_strcpy_s(char* dest, size_t size, const char* src) {
        strlcpy(dest, src, size);
    }

    template <size_t Size>
    inline void jg_strcpy_s(char (&dest)[Size], const char* src) {
        strlcpy(dest, src, Size);
    }

    template <typename... Args>
    inline int jg_printf_s(char* dest, size_t size, const char* format, Args... args) {
        return snprintf(dest, size, format, args...);
    }

    template <size_t Size, typename... Args>
    inline int jg_printf_s(char (&dest)[Size], const char* format, Args... args) {
        return snprintf(dest, Size, format, args...);
    }

#endif

