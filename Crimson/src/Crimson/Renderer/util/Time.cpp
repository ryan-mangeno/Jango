#include "cnpch.h"

#include "Crimson/Renderer/util/Time.h"
#include <GLFW/glfw3.h>

namespace Crimson {
	double GetTime() {
		return glfwGetTime();
	}
}