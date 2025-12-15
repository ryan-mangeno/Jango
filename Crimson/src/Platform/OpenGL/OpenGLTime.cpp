#include "cnpch.h"
#include "OpenGLTime.h"
#include <glad/glad.h>
#include <GLFW/glfw3.h>

namespace Crimson {


	double OpenGLGetTime() {
		return glfwGetTime();
	}


}