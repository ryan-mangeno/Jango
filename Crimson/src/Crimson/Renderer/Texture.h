#pragma once
#include "Crimson/Core/Core.h"
#include "Crimson/Core/UUID.h"

namespace Crimson {
	class Texture
	{
	public:
		uint64_t uuid;
		Texture() = default;
		virtual ~Texture() = default;
		virtual uint32_t GetWidth() const = 0;
		virtual uint32_t GetHeight() const = 0;
		virtual uint32_t GetID() const = 0;
		virtual void Bind(int slot) const = 0;
	};
	class Texture2D :public Texture {
	public:

		static bool ValidateTexture(const std::string& path);
		virtual void UnBind()const = 0;
		virtual unsigned short* GetTexture() = 0;
		virtual uint32_t GetChannels() = 0;
		static Ref<Texture2D> Create(const std::string& path, bool bUse16BitTexture = false);
		static Ref<Texture2D> Create(const uint32_t Width, const uint32_t Height, uint32_t);
	};
	class Texture2DArray : public Texture {
	public:
		virtual void UnBind() const = 0;
		//default number of materials =1 , number of channels = 3
		static Ref<Texture2DArray> Create(const std::vector<std::string>& paths, int numMaterials = 1, int numChannels = 3, bool bUse16BitTexture = false);
	};
}
