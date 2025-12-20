#pragma once

#include <memory>


#ifdef CN_DEBUG
#if CN_PLATFORM_WINDOWS
#define CN_DEBUGBREAK() __debugbreak()
#elif CN_PLATFORM_MACOS
#define CN_DEBUGBREAK() __builtin_debugtrap()
#else
#error "This platform is not supported"
#endif

#else
#define CN_DEBUGBREAK()
#endif // CN_DEBUG


#ifdef CN_ENABLE_ASSERTS
	#define CN_ASSERT(x, ...) {if(!(x)) { CN_ERROR("Assertion Failed: {0}", __VA_ARGS__); CN_DEBUGBREAK(); } }
	#define CN_CORE_ASSERT(x, ...) {if(!(x)) { CN_CORE_ERROR("Assertion Failed: {0}", __VA_ARGS__); CN_DEBUGBREAK(); } }
#else
	#define CN_ASSERT(x, ...)
	#define CN_CORE_ASSERT(x, ...) 
#endif



#define BIT(x) (1 << x )


#define	CN_BIND_EVENT_FN(fn) std::bind(&fn, this, std::placeholders::_1)


#define GAMMA 2.2

//engine texture slots
#define ALBEDO_SLOT 1
#define ROUGHNESS_SLOT 2
#define NORMAL_SLOT 3
#define ENV_SLOT 4
#define IRR_ENV_SLOT 5
#define SHDOW_MAP1 6
#define SHDOW_MAP2 7
#define SHDOW_MAP3 8
#define SHDOW_MAP4 9
#define SSAO_SLOT 10
#define SSAO_BLUR_SLOT 11
#define NOISE_SLOT 12
#define SCENE_TEXTURE_SLOT 13
#define SCENE_DEPTH_SLOT 14
#define ORIGINAL_SCENE_TEXTURE_SLOT 15
#define HEIGHT_MAP_TEXTURE_SLOT 16
#define FOLIAGE_DENSITY_TEXTURE_SLOT 17
#define PERLIN_NOISE_TEXTURE_SLOT 18
#define BLUE_NOISE_TEXTURE_SLOT 29
#define G_COLOR_TEXTURE_SLOT 20
#define G_NORMAL_TEXTURE_SLOT 21
#define G_ROUGHNESS_METALLIC_TEXTURE_SLOT 22
#define G_VELOCITY_BUFFER_SLOT 23
#define LUT_SLOT 24
#define PT_IMAGE_SLOT 25 //Image slot for path tracing to copy the accmulated image
#define HISTORY_TEXTURE_SLOT 26
#define TERRAIN_MASK_TEXTURE_SLOT 27

namespace Crimson {

	template<typename T>
	using Scope = std::unique_ptr<T>;

	template<typename T>
	using Ref = std::shared_ptr<T>;


	template<typename T, typename ... Args>
	constexpr Scope<T> MakeScope(Args&& ... args)
	{
		return std::make_unique<T>(std::forward<Args>(args)...);
	}


	template<typename T, typename... Args>
	constexpr Ref<T> MakeRef(Args&& ... args)
	{
		return std::make_shared<T>(std::forward<Args>(args)...);
	}


}