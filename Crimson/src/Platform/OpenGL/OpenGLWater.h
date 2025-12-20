#pragma once


#include "Crimson/Renderer/Water.h"
#include "OpenGLFrameBuffer.h"

namespace Crimson {


	/*
	
		For OpenGL impl for water, I will optionally have a refraction and reflection, or a low-res version
		for a efficency and or style choice for user
		
		for reflection and refraction there will need to be two fbos

			reflection -> we will place our camera at 2 * cur distance above water down, invert camera rotation, and sample the fbo texture
						  that is above the water, we will also create a clip space using a plane equation for more efficient sampling

			refraction -> keep camera where it is and sample the scene from below the plane ( below the top of the water ) and sample that to the other fbo
						  
		with these two fbos we can sample the textures and give us a resulting texture to put on the water quad

		these fbo visualizations will be availing in imgui menu when one is created, im currently deciding wether or not water will just encomas
		the whole terrain with some height level meaning water will be visible below that line
	*/

	class OpenGLWater : public Water
	{

	public:
		OpenGLWater(const glm::vec3& dims, const glm::vec4& water_color, const glm::vec2& screen_size);
		~OpenGLWater() = default;

		virtual void SetWaterParameters(const glm::vec3& dims, const glm::vec4& water_color) override;
		virtual void RenderWater(Camera& cam, const glm::vec2& screen_size) override;

		virtual float GetHeight() const override { return m_dims.y; };

		inline virtual uint32_t GetReflectionFboID() const override { return m_Fbo1->GetSceneTextureID(); }
		inline virtual const glm::uvec2& GetReflectionViewport() const override { return m_Fbo1->GetSpecification().viewport; }
		inline virtual void BindReflectionFBO() const override { m_Fbo1->Bind(); }
		inline virtual void UnbindReflectionFBO() const override { m_Fbo1->UnBind(); }

		inline virtual uint32_t GetRefractionFboID() const override { return m_Fbo2->GetSceneTextureID(); }
		inline virtual const glm::uvec2& GetRefractionViewport() const override { return m_Fbo2->GetSpecification().viewport; }
		inline virtual void BindRefractionFBO() const override { m_Fbo2->Bind(); }
		inline virtual void UnbindRefractionFBO() const override { m_Fbo2->UnBind(); }


	private:

		Ref<Shader> m_waterShader;
		Ref<FrameBuffer> m_Fbo1;
		Ref<FrameBuffer> m_Fbo2;

		Ref<VertexArray> m_VAO;
		Ref<VertexBuffer> m_VBO;
		Ref<IndexBuffer> m_EBO;
		Ref<BufferLayout> m_Bl;

		glm::vec3 m_dims;
		glm::vec4 m_waterColor = glm::vec4(0.f, 0.f, 1.f, 1.f);
		glm::vec2 m_screenSize;



	};



}