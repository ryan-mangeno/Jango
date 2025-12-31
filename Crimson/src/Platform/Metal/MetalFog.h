#pragma once
#include "Crimson/Renderer/Fog.h"

namespace Crimson
{
	class MetalFog :public Fog
	{
	public:
		MetalFog();
		MetalFog(float density, float fogStart, float fogEnd, float fogTop, float fogBottom, glm::vec2 ScreenSize);
		~MetalFog();

		void RenderFog(Camera& cam, const glm::vec2& screenSize) override;
		void SetFogParameters(float density, float fogTop, float fogEnd, const glm::vec3& fogColor) override { m_density = density, m_fogEnd = fogEnd, m_fogTop = fogTop, m_fogColor = fogColor; }

	private:
		void RenderQuad();
	private:

		Ref<Shader> m_fogShader;
		uint32_t m_framebufferID, m_renderBufferID, m_textureID;
		
		Ref<VertexArray> m_VAO;
		Ref<VertexBuffer> m_VBO;
		Ref<IndexBuffer> m_EBO;
		Ref<BufferLayout> m_Bl;

		float m_density, m_gradient, m_fogStart, m_fogEnd, m_fogTop, m_fogBottom;
		glm::vec3 m_fogColor = glm::vec3(1, 1, 1);
		glm::vec2 m_screenSize;
	};
}