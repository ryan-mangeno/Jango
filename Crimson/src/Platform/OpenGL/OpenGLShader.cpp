#include "cnpch.h"
#include "OpenGLShader.h"
#include "glad/glad.h"
#include "glm/gtc/type_ptr.hpp"

namespace Crimson {


	Shaders OpenGLShader::m_Shaders; 

	//not adding geometry shader feature here as this different shader technique is not used for now
	OpenGLShader::OpenGLShader(const std::string& vertexshader, const std::string& fragmentshader, const std::string& name)
		: m_Name(name)
	{

		unsigned int vs = glCreateShader(GL_VERTEX_SHADER);
		const char* chr = vertexshader.c_str();
		glShaderSource(vs, 1, &chr, nullptr);
		glCompileShader(vs);
		{
			int id = -1; 
			glGetShaderiv(vs, GL_COMPILE_STATUS, &id);
			if (id == GL_FALSE)//if the shader code is not successfully compiled
			{
				int length = -1;
				glGetShaderiv(vs, GL_INFO_LOG_LENGTH, &length);
				char* message = new char[length];
				glGetShaderInfoLog(vs, length, &length, message);
				CN_CORE_ERROR(message);
				delete []message;
			}

		}

		unsigned int fs = glCreateShader(GL_FRAGMENT_SHADER);
		const char* chr1 = fragmentshader.c_str();
		glShaderSource(fs, 1, &chr1, nullptr);
		glCompileShader(fs);

		int id = -1;
		glGetShaderiv(fs, GL_COMPILE_STATUS, &id);
		if (id)
		{
			int length;
			glGetShaderiv(fs, GL_INFO_LOG_LENGTH, &length);
			char* message = new char[length];
			glGetShaderInfoLog(fs, length, &length, message);
			CN_CORE_ERROR(message);
			delete []message;
		}

		m_ID = glCreateProgram();
		glAttachShader(m_ID, vs);
		glAttachShader(m_ID, fs);
		glLinkProgram(m_ID);
		glValidateProgram(m_ID);

		glUseProgram(m_ID);
	}

	OpenGLShader::OpenGLShader(const std::string& path)
	{

		m_Name = std::filesystem::path(path).stem().string();

		m_ID = glCreateProgram();

		m_Shaders = ParseFile(path);
		if (m_Shaders.ComputeShader != "")
		{
			unsigned int cs = CompileShader(m_Shaders.ComputeShader, GL_COMPUTE_SHADER);
			glAttachShader(m_ID, cs);
		}
		else
		{
			unsigned int vs = CompileShader(m_Shaders.VertexShader, GL_VERTEX_SHADER);
			unsigned int fs = CompileShader(m_Shaders.Fragmentshader, GL_FRAGMENT_SHADER);

			glAttachShader(m_ID, vs);
			glAttachShader(m_ID, fs);
		}

		if (m_Shaders.GeometryShader != "")// all optional shaders must be done in this manner
		{
			unsigned int gs = CompileShader(m_Shaders.GeometryShader, GL_GEOMETRY_SHADER);
			glAttachShader(m_ID, gs);
		}

		if (m_Shaders.TessellationControlShader != "")
		{
			unsigned int tcs = CompileShader(m_Shaders.TessellationControlShader, GL_TESS_CONTROL_SHADER);
			glAttachShader(m_ID, tcs);
		}

		if (m_Shaders.TessellationEvaluationShader != "")
		{
			unsigned int tes = CompileShader(m_Shaders.TessellationEvaluationShader, GL_TESS_EVALUATION_SHADER);
			glAttachShader(m_ID, tes);
		}

		glLinkProgram(m_ID);
		glValidateProgram(m_ID);

		glUseProgram(m_ID);
	}

	OpenGLShader::~OpenGLShader()
	{
		glDeleteProgram(m_ID);
	}

	unsigned int OpenGLShader::CompileShader(std::string& Shader, unsigned int type)
	{
		unsigned int program = glCreateShader(type);
		const char* chr = Shader.c_str();
		int length = Shader.size();
		glShaderSource(program, 1, &chr, nullptr);
		glCompileShader(program);

		int id = -1;
		glGetShaderiv(program, GL_COMPILE_STATUS, &id);
		if (id == GL_FALSE)//if the shader code is not successfully compiled
		{
			int length = -1;
			glGetShaderiv(program, GL_INFO_LOG_LENGTH, &length);
			char* message = new char[length];
			glGetShaderInfoLog(program, length, &length, message);
			CN_CORE_ERROR(message);
			delete []message;
		}

		return program;
	}

	Shaders OpenGLShader::ParseFile(const std::string& path)
	{
		enum type 
		{
			VERTEX_SHADER, 
			FRAGMENT_SHADER, 
			GEOMETRY_SHADER, 
			TESS_CONTROL_SHADER, 
			TESS_EVALUATION_SHADER, 
			COMPUTE_SHADER
		};

		std::ifstream stream(path);
		if (!stream)
		{
			CN_CORE_ERROR("Shader File Not Found: ", path);
		}

		std::string ShaderCode("");
		std::string Shader[6] = { "", "", "", "", "", ""};//as for now there are 6 shader types
		int index = -1;

		while (std::getline(stream, ShaderCode))
		{
			if (ShaderCode.find("#shader vertex") != std::string::npos)
			{
				index = type::VERTEX_SHADER;
			}

			else if (ShaderCode.find("#shader fragment") != std::string::npos)
			{
				index = type::FRAGMENT_SHADER;
			}

			else if (ShaderCode.find("#shader geometry") != std::string::npos)
			{
				index = type::GEOMETRY_SHADER;
			}

			else if (ShaderCode.find("#shader tessellation control") != std::string::npos)
			{
				index = type::TESS_CONTROL_SHADER;
			}

			else if (ShaderCode.find("#shader tessellation evaluation") != std::string::npos)
			{
				index = type::TESS_EVALUATION_SHADER;
			}

			else if (ShaderCode.find("#shader compute") != std::string::npos)
			{
				index = type::COMPUTE_SHADER;
			}

			else
			{
				CN_CORE_ASSERT( (index >= 0 && index < 6) , "Invalid Shader");
				Shader[index].append(ShaderCode + "\n");
			}
		}

		return { Shader[0], Shader[1], Shader[2], Shader[3], Shader[4], Shader[5] };
	}

	void OpenGLShader::Bind() const
	{
		glUseProgram(m_ID);
	}

	void OpenGLShader::UnBind() const
	{
		glUseProgram(0);
	}

	void OpenGLShader::SetMat4(const std::string& str, const glm::mat4& UniformMat4, size_t count) const
	{
		UploadUniformMat4(str, UniformMat4, count);
	}

	void OpenGLShader::SetInt(const std::string& str, const int& UniformInt) const
	{
		UploadUniformInt(str, UniformInt);
	}

	void OpenGLShader::SetFloat(const std::string& str, const float& UniformFloat) const
	{
		UpladUniformFloat(str, UniformFloat);
	}

	void OpenGLShader::SetFloatArray(const std::string& str, float& UniformFloatArr, size_t count) const
	{
		UpladUniformFloatArray(str, count, UniformFloatArr);
	}

	void OpenGLShader::SetFloat4(const std::string& str, const glm::vec4& UniformFloat4) const
	{
		UpladUniformFloat4(str, UniformFloat4);
	}

	void OpenGLShader::SetFloat3(const std::string& str, const glm::vec3& UniformFloat3) const
	{
		UpladUniformFloat3(str, UniformFloat3);
	}

	void OpenGLShader::SetFloat3Array(const std::string& str, const float* pointer, size_t count) const
	{
		UpladUniformFloat3Array(str, pointer, count);
	}

	void OpenGLShader::SetFloat4Array(const std::string& str, const float* arr, size_t count) const
	{
		UpladUniformFloat4Array(str, arr, count);
	}

	void OpenGLShader::SetIntArray(const std::string& str, const size_t size, const void* pointer) const
	{
		UploadIntArray(str, size, pointer);
	}

	void OpenGLShader::UploadUniformMat4(const std::string& str, const glm::mat4& UniformMat4, size_t count) const
	{
		uint32_t location = glGetUniformLocation(m_ID, str.c_str());
		glUniformMatrix4fv(location, count, false, glm::value_ptr(UniformMat4));

	}

	void OpenGLShader::UploadUniformInt(const std::string& str, const int& UniformInt) const
	{
		uint32_t location = glGetUniformLocation(m_ID, str.c_str());
		glUniform1i(location, UniformInt);
	}

	void OpenGLShader::UploadIntArray(const std::string& str, const size_t size, const void* pointer) const
	{
		uint32_t location = glGetUniformLocation(m_ID, str.c_str());
		glUniform1iv(location, size, (const GLint*)pointer);
	}

	void OpenGLShader::UpladUniformFloat(const std::string& str, const float& UniformFloat) const
	{
		uint32_t location = glGetUniformLocation(m_ID, str.c_str());
		glUniform1f(location, UniformFloat);
	}

	void OpenGLShader::UpladUniformFloatArray(const std::string& str, size_t count, float& UniformFloatArr) const
	{
		uint32_t location = glGetUniformLocation(m_ID, str.c_str());
		glUniform1fv(location, count, &UniformFloatArr);
	}

	void OpenGLShader::UpladUniformFloat4(const std::string& str, const glm::vec4& UniformFloat4) const
	{
		uint32_t location = glGetUniformLocation(m_ID, &str[0]);
		glUniform4f(location, UniformFloat4.r, UniformFloat4.g, UniformFloat4.b, UniformFloat4.a);
	}
	void OpenGLShader::UpladUniformFloat3(const std::string& str, const glm::vec3& UniformFloat3) const
	{
		uint32_t location = glGetUniformLocation(m_ID, str.c_str());
		glUniform3f(location, UniformFloat3.x, UniformFloat3.y, UniformFloat3.z);
	}
	void OpenGLShader::UpladUniformFloat3Array(const std::string& str, const float* pointer, size_t count) const 
	{
		uint32_t location = glGetUniformLocation(m_ID, str.c_str());
		glUniform3fv(location, count, (const float*)pointer);
	}
	void OpenGLShader::UpladUniformFloat4Array(const std::string& str, const float* pointer, size_t count) const
	{
		uint32_t location = glGetUniformLocation(m_ID, str.c_str());
		glUniform4fv(location, count, (const float*)pointer);
	}
}

// not needed right now
// 	int OpenGLShader::GetUniform(const std::string& name)
// 	{
// 
// 		CN_PROFILE_FUNCTION()
// 
// 		if (m_UniformCache.find(name) != m_UniformCache.end())
// 			return m_UniformCache[name];
// 
// 		int loc = glGetUniformLocation(m_RendererID, name.c_str());
// 		if (loc == -1) {
// 			CN_CORE_ERROR("Uniform ( {0} ) does not exist!", name)
// 		}
// 		else {
// 			m_UniformCache[name] = loc;
// 		}
// 		return loc;
// 	}
