#pragma once
#include "Crimson.h"
#include "Crimson/Renderer/SSAO.h"

#define RANDOM_SAMPLES_SIZE 64
namespace Crimson {
	class OpenGLSSAO : public SSAO
	{

	public:

		OpenGLSSAO(int width, int height);
		~OpenGLSSAO();

		inline void SetSSAO_TextureDimension(int width, int height) override { m_width = width, m_height = height; }
		inline GPUHandle GetSSAOTextureHandle() override { return GPUHandle(SSAOtexture_id); }

		void CaptureScene(Scene& scene , Camera& cam) override;
		void CreateSSAOTexture(int width, int height) override;

	private:

		void RenderScene(Scene& scene , Ref<Shader>& current_shader);// This will be changed later
		void RenderTerrain(Scene& scene, Ref<Shader>& current_shader1, Ref<Shader>& current_shader2);// This will be changed later
		void RenderQuad();

		int m_width=2048, m_height=2048;

		uint32_t SSAOframebuffer_id;
		uint32_t SSAOtexture_id;
		uint32_t GBufferPos_id;
		uint32_t SSAOdepth_id;
		uint32_t SSAOblur_id;
		uint32_t depth_id;
		uint32_t noisetex_id;

		Ref<Shader> SSAOShader;
		Ref<Shader> GbufferPosition;
		Ref<Shader> GbufferPosition_Terrain;
		Ref<Shader> GbufferPositionInstanced;
		Ref<Shader> SSAOblurShader;
		Ref<Shader> SSAOShader_Terrain;
		Ref<FrameBuffer> framebuffer;

		glm::vec3 m_Samples[RANDOM_SAMPLES_SIZE];

		//Camera cam;
	};
}