#pragma once
#include "Crimson.h"
#define RANDOM_SAMPLES_SIZE 64
namespace Crimson {
	class MetalSSAO
	{

	public:

		MetalSSAO(int width, int height);
		~MetalSSAO();

		inline void SetSSAO_TextureDimension(int width, int height) { m_width = width, m_height = height; }
		void CaptureScene(Scene& scene , Camera& cam);
		unsigned int GetSSAOid() { return SSAOblur_id; }
		void CreateSSAOTexture(int width, int height);

	private:
		void RenderScene(Scene& scene , Ref<Shader>& current_shader);// This will be changed later
		void RenderTerrain(Scene& scene, Ref<Shader>& current_shader1, Ref<Shader>& current_shader2);// This will be changed later
		void RenderQuad();
		int m_width=2048, m_height=2048;
		unsigned int SSAOframebuffer_id,SSAOtexture_id,GBufferPos_id , SSAOdepth_id , SSAOblur_id, depth_id;
		unsigned int noisetex_id;
		Ref<Shader> SSAOShader,GbufferPosition, GbufferPosition_Terrain, GbufferPositionInstanced, SSAOblurShader;//temporary
		Ref<Shader> SSAOShader_Terrain;
		Ref<FrameBuffer> framebuffer;
		glm::vec3 samples[RANDOM_SAMPLES_SIZE];
		//Camera cam;
	};
}