#pragma once
#include "Entity.h"
#include "Crimson/Events/ApplicationEvent.h"
#include "Crimson/Events/KeyEvent.h"
#include "Crimson/Events/MouseEvent.h"

namespace Crimson
{
	//Script class Which must be inherited to write custom scripts
	class ScriptableEntity
	{
	public:
		Entity* m_Entity = nullptr;
		friend class Scene;
		std::pair<size_t, ScriptableEntity*> m_scriptPair;

	public:
		ScriptableEntity() = default;
		
		virtual ~ScriptableEntity() {
			//delete m_Entity;
		}

		//overridable methods
		virtual void OnUpdate(TimeStep ts){}
		virtual void OnEvent(Event& e) {}
		virtual void OnCreate(){}
		virtual void OnDestroy(){}

	};
	//std::unordered_map<size_t, ScriptableEntity*> ScriptableEntity::m_scriptMap = {};
}