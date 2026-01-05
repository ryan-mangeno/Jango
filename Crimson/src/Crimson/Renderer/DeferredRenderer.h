#include "Crimson.h"

namespace Crimson
{
	class DefferedRenderer
	{
	public:
		static void Init(int width, int height);
		static void GenerateGBuffers(Scene*, bool withWater);
		static void DeferredRenderPass();
		static Ref<Shader> GetDeferredPassShader();
		static uintptr_t GetBuffers(uint32_t bufferInd);
	};
}
