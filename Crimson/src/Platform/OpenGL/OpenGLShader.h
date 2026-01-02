
#pragma once
#include "Crimson/Core/Log.h"
#include "glm/glm.hpp"
#include "Crimson/Renderer/Shader.h"
namespace Crimson {

	struct Shaders 
	{
		std::string VertexShader;
		std::string Fragmentshader;
		std::string GeometryShader;
		std::string TessellationControlShader;
		std::string TessellationEvaluationShader;
		std::string ComputeShader;
	};

	class OpenGLShader : public Shader 
	{
	public:

		struct ShaderProgramSource
 		{
 			std::string VertexSource;
 			std::string FragmentSource;
		};

		OpenGLShader(const std::string& vertexshader, const std::string& fragmentshader, const std::string& name);
		OpenGLShader(const std::string& path);
		~OpenGLShader();

		virtual void Bind() const override;
		virtual void UnBind() const override;

		virtual void SetMat4(const std::string& str, const glm::mat4& UniformMat4, size_t count = 1) override;
		virtual void SetInt(const std::string& str, const int& UniformInt) override;
		virtual void SetIntArray(const std::string& str, const size_t size, const void* pointer) override;
		virtual void SetFloat(const std::string& str, const float& UniformFloat) override;
		virtual void SetFloatArray(const std::string& str, float& UniformFloat, size_t count) override;
		virtual void SetFloat4(const std::string& str, const glm::vec4& UniformFloat4) override;
		virtual void SetFloat4Array(const std::string& str, const float* arr, size_t count) override;
		virtual void SetFloat3(const std::string& str, const glm::vec3& UniformFloat3) override;
		virtual void SetFloat3Array(const std::string& str, const float* pointer, size_t count)  override;
		//void SetFloat2(const std::string& str, const glm::vec2& UniformFloat2) override; need to make
		//void SetFloat2Array(const std::string& str, const glm::vec2& UniformFloat2) override;

		virtual const std::string& GetName() const override { return m_Name; }

	private:

		uint32_t CompileShader(std::string&, uint32_t);
		Shaders ParseFile(const std::string& path);

		void UploadUniformMat4(const std::string& str, const glm::mat4& UniformMat4, size_t count = 1) const;
		void UploadUniformInt(const std::string& str, const int& UniformInt) const;
		void UploadIntArray(const std::string& str, const size_t size, const void* pointer) const;
		void UpladUniformFloat(const std::string& str, const float& UniformFloat) const;
		void UpladUniformFloatArray(const std::string& str, size_t count, float& UniformFloat) const;
		void UpladUniformFloat4(const std::string& str, const glm::vec4& UniformFloat4) const;
		void UpladUniformFloat3(const std::string& str, const glm::vec3& UniformFloat3) const;
		void UpladUniformFloat3Array(const std::string& str, const float* pointer, size_t count) const;
		void UpladUniformFloat4Array(const std::string& str, const float* pointer, size_t count) const;
		//void UpladUniformFloat2(const std::string& str, const glm::vec3& UniformFloat2); // need to make
		//void UpladUniformFloat2Array(const std::string& str, const float* pointer, size_t count);

		uint32_t m_ID;
		std::string m_Name;
		static Shaders m_Shaders;
	};
}
