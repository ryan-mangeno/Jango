#pragma once
#include "Crimson.h"
#include "Crimson/Renderer/CubeMapReflection.h"
#include "Crimson/Scene/Scene.h"

namespace Crimson {
	class MetalCubeMapReflection:public CubeMapReflection
	{
	public:
		MetalCubeMapReflection();
		~MetalCubeMapReflection();
		void CreateCubeMapTexture();
		virtual void RenderToCubeMap(Scene& scene) override;
		virtual void Bind(uint32_t slot) override;
		virtual void UnBind() override;
		virtual uint32_t GetTexture_ID() override;
		virtual void SetCubeMapResolution(float width, float height) override;
		void SwitchToFace(int n);

	private:
		uint32_t tex_id, framebuffer_id,depth_id;
		Ref<Shader> shader;
		float cubemap_width;
		float cubemap_height;
		int slot = 10;
		float yaw = 0, pitch = 0;
	};
}