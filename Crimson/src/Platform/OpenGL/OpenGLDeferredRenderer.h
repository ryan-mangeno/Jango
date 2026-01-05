#include "Crimson.h"

namespace Crimson
{
	class OpenGLDeferredRenderer
	{
	public:
		static void Init(int width, int height);
		static void CreateBuffers(Scene* scene, bool withWater);
		static void DeferredPass();
		static Ref<Shader> GetDeferredShader() { return m_DefferedPassShader; }
		static uintptr_t GetBuffers(uint32_t bufferInd);

	private:

		static void RenderEntities(Scene* scene);

		static uint32_t m_FramebufferID;
		static uint32_t m_RenderBufferID;
		static uint32_t m_AlbedoBufferID;
		static uint32_t m_NormalBufferID;
		static uint32_t m_RoughnessMetallicBufferID;
		static uint32_t m_VelocityBufferID;

		static Ref<Shader> m_ForwardPassShader;
		static Ref<Shader> m_DefferedPassShader;
	};
}