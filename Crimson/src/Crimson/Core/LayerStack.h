#pragma once

#include "cnpch.h"

#include "Crimson/Core/Core.h"
#include "Layer.h"

namespace Crimson {


	// layer stack is owned by the application
	// for now the layers will be constant for the applications entire duration
	// in the future i will probably rewrite this so if the user changes layers 
	// that the layer destruction will happen automatically and it will not be the users job
	// to delete the layers, which is currently what is happening here
	// if the user pops a layer or overlay, it is their job to delete it, same for allocations


	class LayerStack
	{
	public:
		LayerStack();
		~LayerStack();

		void PushLayer(Layer* layer);
		void PushOverlay(Layer* overlay);
		void PopLayer(Layer* layer);
		void PopOverlay(Layer* overlay);

		// layers will be put into first half of list
		// overlays in second half of the list
		
		// alows us to iterate over layers in range based for loop in our application
		std::vector<Layer*>::iterator begin() { return m_Layers.begin(); }
		std::vector<Layer*>::iterator end() { return m_Layers.end(); }

	private:
		
		// every frame these need to be iterated over for things like updates
		// this is not an actual stack, because we will end up pushing layers in the middle
		// this is to avoid overhead of having two seperate lists for layers and overlays
		// also because overlays and layers are very similar

		std::vector<Layer*> m_Layers;

		// we keep a iterator offset since iterators can be invalidated when pushing
		// and erasing elements from container  and also reallocations
		uint32_t m_LayerIteratorOffset;
	};

}