#pragma once

#include "cnpch.h"

#include "Crimson/Core/Core.h"


namespace Crimson {

	// Events in Crimson are blocking as of now, 
	// when an event occurs it gets sent out and proccessed immediatly
	// to include - batch events and proccess during event section of update stage

	enum class EventType
	{
		None = 0,
		WindowClose, WindowResize, WindowFocus, WindowLostFocus, WindowMoved,
		AppTick, AppUpdate, AppRender,
		KeyPressed, KeyReleased, KeyTyped,
		MouseButtonPressed, MouseButtonReleased, MouseMoved, MouseScrolled
	};

	// bit feild to apply multiple events
	// some events are both keyboard and input
	enum EventCategory
	{
		None = 0,
		EventCategoryApplication     = BIT(0),
		EventCategoryInput           = BIT(1),
		EventCategoryKeyboard        = BIT(2),
		EventCategoryMouse           = BIT(3),
		EventCategoryMouseButton     = BIT(4),
	};



	  
/* reduces code size, allows us to override and define derived classes quickly
 
 return EventType::##type; -> ## operator concatenates, so if we call EVENT_CLASS_TYPE(Mouse)
 we will get return EventType::Mouse in GetStaicType
 
 # operator in GetName func is to stringify, once again these defines dont change any underlying logic
 , just for efficiency and reusability
*/


#ifdef CN_PLATFORM_WINDOWS

#define EVENT_CLASS_TYPE(type) static EventType GetStaticType() { return EventType::##type; }\
							    virtual EventType GetEventType() const override { return GetStaticType(); }\
								virtual const char* GetName() const override { return #type; }

#elif CN_PLATFORM_MACOS

#define EVENT_CLASS_TYPE(type) static EventType GetStaticType() { return EventType::type; }\
							    virtual EventType GetEventType() const override { return GetStaticType(); }\
								virtual const char* GetName() const override { return #type; }

#endif 


#define EVENT_CLASS_CATEGORY(category) virtual int GetCategoryFlags() const override { return category; }





	//Event class that will represent blueprints for all different types of Events in the engine relating
	//to window resizing, key pressed, mouse presses, releases, etc.
	class Event
	{
		// to access private and protected members of EventDispatcher class
		friend class EventDispatcher;

	public:
		virtual EventType GetEventType() const = 0;
		virtual const char* GetName() const = 0;
		virtual int GetCategoryFlags() const = 0;
		virtual std::string ToString() const { return GetName(); }

		inline bool GetHandled() const { return m_Handled; }
		inline bool IsInCategory(EventCategory category) const
		{
			// bitwise & to check flags, refer to EventCategory BIT and #define BIT in Core.h
			// simply to check if the category flag exists in the event's category flags

			return GetCategoryFlags() & category;
		}
	protected:
		// to be able to see if event has been handled or not
		// we will disbatch events to different layers, we may want to decide
		// that we don't want an event to propogate further
		bool m_Handled = false;

	};

	/* @param takes in some Event to dispatch
	    

	 @brief for example:
	 
		If we wanted to dispatch mouse button presses
		we would possibly call disbatch with however many functions we get 
		from some layer to proccess and we will run it if is a mouse button press type
		
		----

	 keeping in mind, we want to keep the window and application seperate, making
	 window call back to the application with events, with the event dispatcher
	 we may pass some function 

	*/       
	class EventDispatcher
	{
		template<typename T>
		using EventFn = std::function<bool(T&)>;

	public:
		EventDispatcher(Event& event)
			: m_Event(event) {}

		template<typename T>
		bool Dispatch(EventFn<T> func)
		{
			if (m_Event.GetEventType() == T::GetStaticType())
			{					
				//(T*)&m_Event) -> casts a T pointer to address of m_Event
				//(*(T*)&m_Event) -> defrefrences the pointer so we can use it as a ref
				m_Event.m_Handled = func(*(T*)&m_Event);
				return true;
			}
			return false;
		}
		

	private:
		Event& m_Event;
	};


	inline std::ostream& operator <<(std::ostream & os, const Event & e)
	{
		return os << e.ToString();
	}

	/* 
	to add

	inline std::ostream& operator <<(std::ostream& os, const crm::mat4& e)
	{
		return os << e.ToString();
	}
	*/

}