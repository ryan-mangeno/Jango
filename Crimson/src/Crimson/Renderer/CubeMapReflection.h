#pragma once
#include "Crimson.h"

namespace Crimson {
	class CubeMapReflection
	{
	public:
		CubeMapReflection();
		~CubeMapReflection();
		virtual void RenderToCubeMap(Scene& scene) = 0;
		virtual void Bind(int slot) = 0;
		virtual void UnBind() = 0;
		virtual unsigned int GetTexture_ID() = 0;
		virtual void SetCubeMapResolution(float width, float height) = 0;
		static Ref<CubeMapReflection> Create();
	};
}