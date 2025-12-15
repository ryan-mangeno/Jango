#include "Crimson.h"

namespace Crimson {
	class Atmosphere {
	public:
		static void RenderAtmosphere(Camera& camera , const float& atmosphere_radius= 6471e3);
		static void InitilizeAtmosphere();
		static void RenderQuad(const glm::mat4& view, const glm::mat4& proj);
	private:
		static Ref<Shader> atmosphere_shader;
		static Ref<Texture2DArray> skyGradients;
	};
}