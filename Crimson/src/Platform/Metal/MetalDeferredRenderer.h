#include "Crimson.h"

namespace Crimson
{
	class MetalDeferredRenderer
	{
	public:
		static void Init(int width, int height);
		static void CreateBuffers(Scene* scene, bool withWater);
		static void DeferredPass();
		static Ref<Shader> GetDeferredShader() { return m_DefferedPassShader; }
		static uint32_t GetBuffers(uint32_t bufferInd);

	private:

		static void RenderEntities(Scene* scene);

		static uint32_t m_framebufferID, m_RenderBufferID, m_AlbedoBufferID,
			m_NormalBufferID , m_RoughnessMetallicBufferID, m_VelocityBufferID;
		static Ref<Shader> m_ForwardPassShader;
		static Ref<Shader> m_DefferedPassShader;
	};
}