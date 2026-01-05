#include "cnpch.h"
#include "Shader.h"
#include "Renderer.h"

#include "Platform/OpenGL/OpenGLShader.h"
#include "Platform/Metal/MetalShader.h"

namespace Crimson {

	Ref<Shader> Shader::Create(const std::string& path)
	{
		// temporary
		std::string tmp(path);
		ShaderPathParse::ParseShader(tmp);
		
		switch (RendererAPI::GetAPI())
		{
		case GraphicsAPI::None:
			return nullptr;
		case GraphicsAPI::OpenGL:
			return MakeRef<OpenGLShader>(tmp);
		case GraphicsAPI::Metal:
			return MakeRef<MetalShader>(tmp);
		default:
			return nullptr;
		}
	}
	Ref<Shader>  Shader::Create(const std::string& vertexshader, const std::string& fragmentshader, const std::string& name)
	{
		switch (RendererAPI::GetAPI())
		{
		case GraphicsAPI::None:
			return nullptr;
		case GraphicsAPI::OpenGL:
			return MakeRef<OpenGLShader>(vertexshader, fragmentshader, name);
		case GraphicsAPI::Metal:
			return MakeRef<MetalShader>(vertexshader, fragmentshader, name);
		default:
			return nullptr;
		}
	}

	void ShaderLibrary::Add(const Ref<Shader>& shader)
	{
		const std::string& name = shader->GetName();
 		CN_CORE_ASSERT(!Exists(name), "Shader Already Exists!");
 		m_Shaders[name] = shader;
	}

	void ShaderLibrary::Add(const Ref<Shader>& shader, const std::string& name)
	{
		CN_CORE_ASSERT(!Exists(name), "Shader Already Exists!");
		m_Shaders[name] = shader;
	}

	Ref<Shader> ShaderLibrary::Load(const std::string& filepath)
	{
		Ref<Shader> shader = Shader::Create(filepath);
		Add(shader);
		return shader;
	}

	Ref<Shader> ShaderLibrary::Load(const std::string& name, const std::string& filepath)
	{
		Ref<Shader> shader = Shader::Create(filepath);
		Add(shader, name);
		return shader;
	}

	Ref<Shader> ShaderLibrary::Get(const std::string& name)
	{
		CN_CORE_ASSERT(Exists(name), "Shader Doesn't Exist!");
		return m_Shaders[name];
	}

	bool ShaderLibrary::Exists(const std::string& name) const
	{
		return m_Shaders.find(name) != m_Shaders.end();
	}

}
