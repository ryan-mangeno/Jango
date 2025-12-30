#pragma once

#include "Crimson/Core/Input.h"

namespace Crimson {
	class MacInput : public Input
	{
		
	protected:
		virtual bool IsKeyPressedImpl(int keycode) const override;

		virtual std::pair<float, float> GetMousePosImpl() const override;
		virtual bool IsMouseButtonPressedImpl(int button) const override;
		virtual float GetMouseXImpl() const override;
		virtual float GetMouseYImpl() const override;

	};
}