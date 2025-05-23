#pragma once
#include "glm/glm.hpp"
#include "glm/gtc/matrix_transform.hpp"
#include "glm/gtc/type_ptr.hpp"
#include "glm/gtx/quaternion.hpp"
#include "Crimson/Events/Event.h"
#include "Crimson/Core/TimeStep.h"

//this is a camera class for camera component so it has no transform , it only has projection matrix
namespace Crimson {
	enum CameraType {
		EDITOR_CAMERA, SCENE_CAMERA
	};
	class Camera {
	public:
		Camera() = default;

		virtual ~Camera() = default;
		virtual void SetPerspctive(float v_FOV, float Near, float Far) = 0;
		virtual void SetCameraPosition(const glm::vec3& pos) = 0;
		virtual void SetViewDirection(const glm::vec3& dir) = 0;
		virtual void SetUPVector(const glm::vec3& up) = 0;
		virtual void SetViewportSize(float aspectratio) = 0;
		virtual void SetVerticalFOV(float fov) = 0;
		virtual void SetPerspectiveNear(float val) = 0;
		virtual void SetPerspectiveFar(float val) = 0;
		virtual void SetViewMatrix(const glm::mat4&) {}
		virtual void Translate(const glm::vec3& translation) = 0;

		virtual float GetPerspectiveNear() = 0;
		virtual float GetPerspectiveFar() = 0;
		virtual inline const glm::mat4& GetProjectionView() = 0;
		virtual inline const glm::mat4& GetViewMatrix() = 0;
		virtual inline const glm::mat4& GetProjectionMatrix() = 0;
		virtual inline const glm::vec3& GetCameraPosition() = 0;
		virtual inline glm::vec3 GetCameraRotation() = 0;
		virtual inline const glm::vec3& GetViewDirection() = 0;
		virtual inline void InvertPitch() = 0;
		virtual inline float GetAspectRatio() = 0;
		virtual inline float GetVerticalFOV() = 0;

		virtual void OnEvent(Event& e) = 0;
		virtual void OnUpdate(TimeStep ts) = 0;
		virtual void RotateCamera(float pitch = 0, float yaw = 0, float roll = 0) = 0;

		static Ref<Camera> GetCamera(CameraType type);
	public:
		bool bIsMainCamera = false;
		bool IsResiziable = true;

	};
}