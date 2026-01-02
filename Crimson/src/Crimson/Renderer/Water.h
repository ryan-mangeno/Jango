#pragma once

#include <Crimson.h>

#include "GPUHandle.h"


namespace Crimson{
	class Water
	{
	public:

		virtual ~Water() = default;

		// dims will define the quad the body of water will exist in
		// for now the water will be a quad, not sculpted to the terrain it exists in
		// since water will exist in depreciated land ( most likely ), edge of water body will be invisible under the terrain
		static Ref<Water> Create(const glm::vec3& dims, const glm::vec4& water_color, const glm::vec2& screen_size);

		// also, screen size is supplied to create since i will make fbo for imgui  // to visualize reflection/refraction

		virtual void SetWaterParameters(const glm::vec3& dims, const glm::vec4& water_color) = 0;
		virtual void RenderWater(Camera& cam, const glm::vec2& screen_size) = 0;

		virtual float GetHeight() const = 0;

		inline virtual GPUHandle GetReflectionTextureHandle() const = 0;
		inline virtual const glm::uvec2& GetReflectionViewport() const = 0;
		inline virtual void BindReflectionFBO() const = 0;
		inline virtual void UnbindReflectionFBO() const = 0;

		inline virtual GPUHandle GetRefractionTextureHandle() const = 0;
		inline virtual const glm::uvec2& GetRefractionViewport() const = 0;
		inline virtual void BindRefractionFBO() const = 0;
		inline virtual void UnbindRefractionFBO() const = 0;
	};

}