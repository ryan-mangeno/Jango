#include "cnpch.h"
#include "MacInput.h"
#include "Crimson/Core/Application.h"

#include <GLFW/glfw3.h>

namespace Crimson {
	// also need to free this for good measure, there is no data but there is still v-table due to ebo

	Input* Input::s_Instance = new MacInput;

	bool MacInput::IsKeyPressedImpl(int keycode) const
	{
		GLFWwindow* window = static_cast<GLFWwindow*>(Application::Get().GetWindow().GetNativeWindow());
		int state = glfwGetKey(window, keycode);
		return state == GLFW_PRESS || state == GLFW_REPEAT;
	}

	std::pair<float, float> MacInput::GetMousePosImpl() const
	{
		GLFWwindow* window = static_cast<GLFWwindow*>(Application::Get().GetWindow().GetNativeWindow());
		double xpos, ypos;
		glfwGetCursorPos(window, &xpos, &ypos);

		return { (float)xpos, (float)ypos };
	}

	bool MacInput::IsMouseButtonPressedImpl(int button) const
	{
		GLFWwindow* window = static_cast<GLFWwindow*>(Application::Get().GetWindow().GetNativeWindow());
		int state = glfwGetMouseButton(window, button);
		return state == GLFW_PRESS;
	}

	float MacInput::GetMouseXImpl() const 
	{
		// structured binding is awzome :))
		auto [x, y] = GetMousePosImpl();
		return x;
	}

	float MacInput::GetMouseYImpl() const
	{
		auto [x, y] = GetMousePosImpl();
		return y;
	}

}
