#pragma once
#include "Crimson.h"

namespace Crimson {
	class CubeMapReflection
	{
	public:
		CubeMapReflection();
		~CubeMapReflection();
		virtual void RenderToCubeMap(Scene& scene) = 0;
		virtual void Bind(uint32_t slot) = 0;
		virtual void UnBind() = 0;
		virtual uint32_t GetTexture_ID() = 0;
		virtual void SetCubeMapResolution(float width, float height) = 0;
		static Ref<CubeMapReflection> Create();
	};
}