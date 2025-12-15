#include "cnpch.h"
#include "OrthographicCameraController.h"
#include "Crimson/Core/Input.h"
#include "Crimson/Core/KeyCodes.h"

#define CN_BIND_FN(x) std::bind(&OrthographicCameraController::x,this,std::placeholders::_1)

namespace Crimson {
	OrthographicCameraController::OrthographicCameraController(float aspectratio)
		:m_AspectRatio(aspectratio), m_Camera(-m_AspectRatio * m_ZoomLevel, m_AspectRatio* m_ZoomLevel, -m_ZoomLevel, m_ZoomLevel)
	{
	}
	void OrthographicCameraController::OnUpdate(TimeStep deltatime)
	{
		if (Input::IsKeyPressed(CRIMSON_KEY_W))
			m_Position.y -= m_MovementSpeed * deltatime;
		if (Input::IsKeyPressed(CRIMSON_KEY_S))
			m_Position.y += m_MovementSpeed * deltatime;
		if (Input::IsKeyPressed(CRIMSON_KEY_A))
			m_Position.x -= m_MovementSpeed * deltatime;
		if (Input::IsKeyPressed(CRIMSON_KEY_D))
			m_Position.x += m_MovementSpeed * deltatime;

		if (m_RotationOn) {
			if (Input::IsKeyPressed(CRIMSON_KEY_Q))
				m_Rotation += m_RotationSpeed * deltatime;
			if (Input::IsKeyPressed(CRIMSON_KEY_E))
				m_Rotation -= m_RotationSpeed * deltatime;
			m_Camera.SetRotation(m_Rotation);
		}

		m_Camera.SetRotation(m_RotationSpeed);
	}
	void OrthographicCameraController::OnEvent(Event& e)
	{
		EventDispatcher dispatcher(e);
		dispatcher.Dispatch<MouseScrolledEvent>(CN_BIND_FN(ZoomEvent));
		dispatcher.Dispatch<WindowResizeEvent>(CN_BIND_FN(WindowResize));
	}
	void OrthographicCameraController::OnResize(float width, float height)
	{
		m_AspectRatio = width / height;
		m_Camera.SetOrthographicProjection(-m_AspectRatio * m_ZoomLevel, m_AspectRatio * m_ZoomLevel, -m_ZoomLevel, m_ZoomLevel);
	}
	bool OrthographicCameraController::ZoomEvent(MouseScrolledEvent& e)
	{
		m_ZoomLevel = std::clamp(m_ZoomLevel - e.GetYOffset(), 1.0f, 30.0f);

		m_Camera.SetOrthographicProjection(-m_AspectRatio * m_ZoomLevel, m_AspectRatio * m_ZoomLevel, -m_ZoomLevel, m_ZoomLevel);
		return false;
	}
	bool OrthographicCameraController::WindowResize(WindowResizeEvent& e)
	{
		m_AspectRatio = (float)e.GetWidth() / (float)e.GetHeight();
		m_Camera.SetOrthographicProjection(-m_AspectRatio * m_ZoomLevel, m_AspectRatio * m_ZoomLevel, -m_ZoomLevel, m_ZoomLevel);
		return false;
	}
}

