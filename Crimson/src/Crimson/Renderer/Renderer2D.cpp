#include "cnpch.h"
#include "Renderer2D.h"
#include "RenderCommand.h"
#include "Buffer.h"
#include "glm/gtc/matrix_transform.hpp"
#include "glm/gtc/type_ptr.hpp"
#include "glad/glad.h"

#define M_TRANSFORM(pos,angle) glm::rotate(glm::mat4(1.0f),glm::radians(angle),{0.0f,0.0f,1.0f})\
 * glm::scale(glm::mat4(1.0f),{1.0f,1.0f,1.0f}) * pos

namespace Crimson {

	struct VertexAttributes {
		//glm::vec3 Position;
		glm::vec4 Position;
		glm::vec2 TextureCoordinate;
		glm::vec4 Color;
		unsigned int TextureSlotindex = 0;//serves as an index to the array of texture slot which is passed as an uniform in init()
		VertexAttributes(glm::vec4 Position, glm::vec2 TextureCoordinate, glm::vec4 Color = { 1,1,1,1 }, unsigned int TextureSlotindex = 0)
		{
			this->Position = Position;
			this->TextureCoordinate = TextureCoordinate;
			this->Color = Color;
			this->TextureSlotindex = TextureSlotindex;
		}
		//may more ..uv coord , tangents , normals..
	};

	struct LineAttributes {
		//attributes for drawing a line
		glm::vec4 Position;
		glm::vec4 Color;
		LineAttributes() = default;
		LineAttributes(const glm::vec4& p1, const glm::vec4& c)
		{
			Position = p1;
			Color = c;
		}
	};

	struct Renderer2DStorage {
		int maxQuads = 10000;
		int NumIndices = maxQuads * 6;
		int NumVertices = maxQuads * 4;

		Ref<VertexArray> vao;
		Ref<VertexArray> Linevao;
		Ref<Shader> shader, Lineshader;
		Ref<Texture2D> WhiteTex;
		Ref<VertexBuffer> vb;
		Ref<VertexBuffer> Linevb;
		//Ref<Texture2D> texture, texture2;

		std::vector< VertexAttributes> Quad;
		std::vector<LineAttributes> Line;
		std::vector<unsigned int> index;
		uint32_t m_VertexCounter = 0;
		uint32_t m_LineVertCounter = 0;
	};
	static Renderer2DStorage* m_data;

	void Renderer2D::StartBatch()
	{
		m_data->m_VertexCounter = 0;
	}

	void Renderer2D::Flush()
	{
		m_data->vb->SetData(sizeof(VertexAttributes) * m_data->m_VertexCounter, &m_data->Quad[0].Position.x);
		RenderCommand::DrawIndex(*m_data->vao, GL_TRIANGLES);//draw call done only once (batch rendering is implemented)
		m_data->m_VertexCounter = 0;
	}

	void Renderer2D::FlushLine()
	{
		m_data->Linevb->SetData(sizeof(LineAttributes) * m_data->m_LineVertCounter, &m_data->Line[0].Position);
		uint32_t x = (2 * m_data->m_LineVertCounter) - 1;
		RenderCommand::DrawLine(*m_data->Linevao, x);
		m_data->m_LineVertCounter = 0;
	}

	void Renderer2D::NextBatch()
	{
		Flush();
		StartBatch();
	}

	void Renderer2D::Init()
	{
		m_data = new Renderer2DStorage;

		//initilize the vertex buffer data and index buffer data
		m_data->Quad.resize(m_data->NumVertices, { glm::vec4(0.0),glm::vec2(0.0),glm::vec4(0.0) });
		m_data->Line.resize(m_data->maxQuads * 2);//allocate space for the vertices that will draw the line
		m_data->index.resize(m_data->NumIndices);

		int offset = 0;
		for (unsigned int i = 0; i < m_data->NumIndices; i += 6)
		{
			m_data->index[i] = offset;
			m_data->index[i + 1] = offset + 1;
			m_data->index[i + 2] = offset + 2;
			m_data->index[i + 3] = offset;
			m_data->index[i + 4] = offset + 3;
			m_data->index[i + 5] = offset + 2;
			offset += 4;
		}

		m_data->Linevao = (VertexArray::Create());
		m_data->vao = (VertexArray::Create());//vertex array

		m_data->Linevb = VertexBuffer::Create((sizeof(LineAttributes) * 2) * m_data->maxQuads);
		m_data->vb = VertexBuffer::Create((sizeof(VertexAttributes) * 4) * m_data->maxQuads);//(sizeof(VertexAttributes)*4) gives one quad multiply it with howmany quads you want

		Ref<BufferLayout> Linebl = std::make_shared<BufferLayout>(); //buffer layout
		Ref<BufferLayout> bl = std::make_shared<BufferLayout>(); //buffer layout

		Linebl->push("position", ShaderDataType::Float4);
		Linebl->push("Color", ShaderDataType::Float4);

		bl->push("position", ShaderDataType::Float4);
		bl->push("TexCoord", ShaderDataType::Float2);
		bl->push("Color", ShaderDataType::Float4);
		bl->push("TextureSlot", ShaderDataType::Int);

		m_data->Linevao->AddBuffer(Linebl, m_data->Linevb);

		Ref<IndexBuffer> ib(IndexBuffer::Create(&m_data->index[0], sizeof(unsigned int) * m_data->NumIndices));
		m_data->vao->AddBuffer(bl, m_data->vb);
		m_data->vao->SetIndexBuffer(ib);


		m_data->WhiteTex = Texture2D::Create(1, 1, 0xffffffff);//create a default white texture
		m_data->Lineshader = (Shader::Create("Assets/Shaders/LineShader.glsl"));
		m_data->shader = (Shader::Create("Assets/Shaders/2_In_1Shader.glsl"));//texture shader

		unsigned int TextureIDindex[] = { 0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31 };

		m_data->shader->SetIntArray("u_Texture", sizeof(TextureIDindex), TextureIDindex);//pass the the array of texture slots
		//which will be used to render textures in batch renderer

		m_data->index.clear();
	}
	void Renderer2D::BeginScene(OrthographicCamera& camera)
	{
		m_data->shader->Bind();//bind the textureShader
		m_data->shader->SetMat4("u_ProjectionView", camera.GetProjectionViewMatix());

		StartBatch();
	}

	//void Renderer2D::BeginScene(Camera& camera)
	//{
	//	m_data->shader->Bind();//bind the textureShader
	//	m_data->shader->SetMat4("u_ProjectionView", camera.GetProjectionMatrix());
	//
	//	StartBatch();
	//}

	void Renderer2D::BeginScene(Camera& camera)
	{
		m_data->shader->Bind();//bind the textureShader
		m_data->shader->SetMat4("u_ProjectionView", camera.GetProjectionView());//here the projection is ProjectionView

		StartBatch();
	}

	void Renderer2D::EndScene()
	{
		Flush();
	}

	void Renderer2D::LineBeginScene(OrthographicCamera& camera)
	{
		m_data->Lineshader->Bind();
		m_data->Lineshader->SetMat4("u_ProjectionView", camera.GetProjectionViewMatix());

		StartBatch();
	}

	void Renderer2D::LineBeginScene(Camera& camera)
	{
		m_data->Lineshader->Bind();
		m_data->Lineshader->SetMat4("u_ProjectionView", camera.GetProjectionView());

		StartBatch();
	}

	void Renderer2D::LineEndScene()
	{
		FlushLine();
	}

	void Renderer2D::DrawQuad(const glm::vec3& pos, const glm::vec3& scale, const glm::vec4& col, const float angle)
	{
		if (m_data->m_VertexCounter >= m_data->NumVertices)
			NextBatch();
		m_data->Quad[m_data->m_VertexCounter + 0] = VertexAttributes(M_TRANSFORM(glm::vec4(pos, 1), angle), { 0.0,0.0 }, col);
		m_data->Quad[m_data->m_VertexCounter + 1] = VertexAttributes(M_TRANSFORM(glm::vec4(pos.x, pos.y + scale.y, pos.z, 1.f), angle), { 0.0,1.0 }, col);
		m_data->Quad[m_data->m_VertexCounter + 2] = VertexAttributes(M_TRANSFORM(glm::vec4(pos.x + scale.x, pos.y + scale.y, pos.z, 1.f), angle), { 1.0,1.0 }, col);
		m_data->Quad[m_data->m_VertexCounter + 3] = VertexAttributes(M_TRANSFORM(glm::vec4(pos.x + scale.x, pos.y, pos.z, 1.f), angle), { 1.0,0.0 }, col);

		m_data->WhiteTex->Bind(0);//bind the white texture so that solid color is selected in fragment shader
		//m_data->shader->SetFloat4("u_color", col);

		m_data->m_VertexCounter += 4;
	}

	void Renderer2D::DrawQuad(const glm::vec3& pos, const glm::vec3& scale, Ref<Texture2D> tex, unsigned int index, const float angle)
	{
		if (m_data->m_VertexCounter >= m_data->NumVertices)
			NextBatch();

		m_data->Quad[m_data->m_VertexCounter + 0] = VertexAttributes(M_TRANSFORM(glm::vec4(pos, 1), angle), { 0,0 }, { 1,1,1,1 }, index);
		m_data->Quad[m_data->m_VertexCounter + 1] = VertexAttributes(M_TRANSFORM(glm::vec4(pos.x, pos.y + scale.y, pos.z, 1.f), angle), { 0,1 }, { 1,1,1,1 }, index);
		m_data->Quad[m_data->m_VertexCounter + 2] = VertexAttributes(M_TRANSFORM(glm::vec4(pos.x + scale.x, pos.y + scale.y, pos.z, 1.f), angle), { 1,1 }, { 1,1,1,1 }, index);
		m_data->Quad[m_data->m_VertexCounter + 3] = VertexAttributes(M_TRANSFORM(glm::vec4(pos.x + scale.x, pos.y, pos.z, 1.f), angle), { 1,0 }, { 1,1,1,1 }, index);

		if (tex)
			tex->Bind(index);
		//m_data->shader->SetFloat4("u_color", glm::vec4(1));//set the multiplying color to white so that the texture is selected in fragment shader

		m_data->m_VertexCounter += 4;
	}

	void Renderer2D::DrawQuad(const glm::mat4& transform, const glm::vec4& color, Ref<Texture2D> texture)
	{
		if (m_data->m_VertexCounter >= m_data->NumVertices)
			NextBatch();

		int k = 0;
		if (texture.get() == nullptr) {
			texture = m_data->WhiteTex;//if the texture is null then bind the white texture to slot 0
		}
		else
			k = 1;//if the texture is not null then bind it to slot 1 (though it is not correct as if there are more than 1
		// Script component then texture will be fetched from the same slot ^_^ :(  :) )

		m_data->Quad[m_data->m_VertexCounter + 0] = VertexAttributes(transform * glm::vec4(0, 0, 0, 1), { 0,0 }, color, k);
		m_data->Quad[m_data->m_VertexCounter + 1] = VertexAttributes(transform * glm::vec4(0, 1, 0, 1), { 0,1 }, color, k);
		m_data->Quad[m_data->m_VertexCounter + 2] = VertexAttributes(transform * glm::vec4(1, 1, 0, 1), { 1,1 }, color, k);
		m_data->Quad[m_data->m_VertexCounter + 3] = VertexAttributes(transform * glm::vec4(1, 0, 0, 1), { 1,0 }, color, k);

		texture->Bind(k);//for now bind at slot 0
		//m_data->WhiteTex->Bind(0);//There is no need to bind the texture every frame .In this case the texture can be bound once and used all the time
		m_data->m_VertexCounter += 4;
		k++;
		k = k % 10;
	}

	void Renderer2D::DrawSubTexturedQuad(const glm::vec3& pos, const glm::vec3& scale, Ref<SubTexture2D> tex, unsigned int index, const float angle)
	{
		if (m_data->m_VertexCounter >= m_data->NumVertices)
			NextBatch();

		m_data->Quad[m_data->m_VertexCounter + 0] = VertexAttributes(M_TRANSFORM(glm::vec4(pos, 1), angle), tex->m_TextureCoordinate[0], { 1,1,1,1 }, index);
		m_data->Quad[m_data->m_VertexCounter + 1] = VertexAttributes(M_TRANSFORM(glm::vec4(pos.x, pos.y + scale.y, pos.z, 1.f), angle), tex->m_TextureCoordinate[1], { 1,1,1,1 }, index);
		m_data->Quad[m_data->m_VertexCounter + 2] = VertexAttributes(M_TRANSFORM(glm::vec4(pos.x + scale.x, pos.y + scale.y, pos.z, 1.f), angle), tex->m_TextureCoordinate[2], { 1,1,1,1 }, index);
		m_data->Quad[m_data->m_VertexCounter + 3] = VertexAttributes(M_TRANSFORM(glm::vec4(pos.x + scale.x, pos.y, pos.z, 1.f), angle), tex->m_TextureCoordinate[3], { 1,1,1,1 }, index);

		tex->Texture->Bind(index);//There is no need to bind the texture every frame .In this case the texture can be bound once and used all the time
		m_data->m_VertexCounter += 4;
	}
	void Renderer2D::DrawLine(const glm::vec3& p1, const glm::vec3& p2, const glm::vec4& color, const float& width)
	{
		if (m_data->m_LineVertCounter >= m_data->maxQuads)
		{
			FlushLine();
			StartBatch();
		}

		m_data->Line[m_data->m_LineVertCounter + 0] = LineAttributes(glm::vec4(p1, 1), color);
		m_data->Line[m_data->m_LineVertCounter + 1] = LineAttributes(glm::vec4(p2, 1), color);
		m_data->m_LineVertCounter += 2;
		glLineWidth(width);
		//glColor4f(0, 1, 0, 1);
	}
	void Renderer2D::DrawCurve(const glm::vec2& p0, const glm::vec2& p1, const glm::vec2& v0, const glm::vec2& v1, const glm::vec4& color, float width)
	{
		//hermite curve implementation best for joining points in a smooth manner
		glm::vec2 p;
		glm::vec3 tmp = glm::vec3(p0, 0.0f);

		for (int i = 1; i <= 10; i++)//iterating the value of t
		{
			float t = (float)i / 10.0;
			p.x = p0.x +
				t * v0.x +
				t * t * (-3 * p0.x - 2 * v0.x + 3 * p1.x - v1.x) +
				t * t * t * (2 * p0.x + v0.x - 2 * p1.x + v1.x);
			p.y = p0.y +
				t * v0.y +
				t * t * (-3 * p0.y - 2 * v0.y + 3 * p1.y - v1.y) +
				t * t * t * (2 * p0.y + v0.y - 2 * p1.y + v1.y);
			Renderer2D::DrawLine(tmp, glm::vec3(p, 0.0f), color, width);
			tmp = glm::vec3(p, 0);
		}

	}
	void Renderer2D::Draw_Bezier_Curve(const glm::vec2& p0, const glm::vec2& p1, const glm::vec2& p2, const glm::vec2& p3)
	{

		glm::vec2 p;
		glm::vec3 tmp = glm::vec3(p0, 0);

		for (int i = 1; i <= 10; i++)//iterating the value of t
		{
			float t = (float)i / 10.0;
			p.x = p0.x +
				t * (-3 * p0.x + 3 * p1.x) +
				t * t * (3 * p0.x - 6 * p1.x + 3 * p2.x) +
				t * t * t * (-p0.x + 3 * p1.x - 3 * p2.x + p3.x);
			p.y = p0.y +
				t * (-3 * p0.y + 3 * p1.y) +
				t * t * (3 * p0.y - 6 * p1.y + 3 * p2.y) +
				t * t * t * (-p0.y + 3 * p1.y - 3 * p2.y + p3.y);
			Renderer2D::DrawLine(tmp, glm::vec3(p, 0), { 0.9,0.4,0.6,1 });
			tmp = glm::vec3(p, 0);
		}
	}
}

// #include "cnpch.h"
// #include "Renderer2D.h"
// 
// #include "VertexArray.h"
// #include "Shader.h"
// 
// #include "Crimson/Renderer/RenderCommand.h"
// #include <glm/glm.hpp>
// 
// namespace Crimson {
// 
// 	#define ROTATE_POS(position,rotation) glm::Mul(glm::ZRotation(rotation), position)
// 
// 	struct QuadVertex
// 	{
// 		glm::vec3 Position;
// 		glm::vec4 Color;
// 		glm::vec2 TexCoord;
// 		uint32_t TexIndex;
// 
// 		QuadVertex() = default;
// 		QuadVertex(glm::vec3 Position, glm::vec2 TexCoord, glm::vec4 Color = { 1.0f , 1.0f , 1.0f , 1.0f }, unsigned int TexIndex = 0)
// 			: Position(Position), Color(Color), TexCoord(TexCoord), TexIndex(TexIndex)
// 		{
// 		}
// 		//..uv coord , tangents , normals..
// 	};
// 
// 	struct LineVertex {
// 
// 		glm::vec3 Position;
// 		glm::vec4 Color;
// 		LineVertex(const glm::vec3& pos, const glm::vec4& color)
// 			: Position(pos), Color(color)
// 		{
// 		}
// 	};
// 
// 
// 	struct Renderer2DData
// 	{
// 		const uint32_t maxQuads = 10000;
// 		const uint32_t maxVerts = maxQuads * 4;
// 		const uint32_t maxIndices = maxQuads * 6;
// 		static const uint32_t maxTextureSlots = 32; // todo render capabilties
// 		
// 		uint32_t QuadIndexCount = 0;
// 		uint32_t LineIndexCount = 0;
// 
// 
// 		uint32_t QuadVertexCount = 0;
// 		uint32_t LineVertexCount = 0;
// 
// 
// 		Ref<VertexArray> QuadVertexArray;
// 		Ref<VertexBuffer> QuadVertexBuffer;
// 		Ref<Shader> TextureShader;
// 		Ref<Texture2D> WhiteTexture;
// 
// 		Ref<VertexArray> LineVertexArray;
// 		Ref<VertexBuffer> LineVertexBuffer;
// 		Ref<Shader> LineShader;
// 
// 
// 		LineVertex* LineVertexBufferBase = nullptr;
// 		LineVertex* LineVertexBufferPtr = nullptr;
// 
// 		QuadVertex* QuadVertexBufferBase = nullptr;
// 		QuadVertex* QuadVertexBufferPtr = nullptr;
// 
// 
// 		std::array<Ref<Texture2D>, maxTextureSlots> TextureSlots;
// 		uint32_t TextureSlotIndex = 1; // white texture : 0
// 
// 	};
// 
// 
// 	static Renderer2DData s_Storage;
// 
// 	void Renderer2D::Init()
// 	{
// 
// 
// 		CN_PROFILE_FUNCTION();
// 
// 		s_Storage.QuadVertexArray = VertexArray::Create();
// 		s_Storage.QuadVertexBuffer = VertexBuffer::Create(s_Storage.maxVerts * sizeof(QuadVertex));
// 
// 		s_Storage.LineVertexArray = (VertexArray::Create());
// 		s_Storage.LineVertexBuffer = VertexBuffer::Create(s_Storage.maxQuads * sizeof(LineVertex)); // temp
// 
// 		BufferLayout QuadLayout(
// 			{ShaderDataType::Float3, "a_Position"},
// 			{ShaderDataType::Float4, "a_Color"},
// 			{ShaderDataType::Float2, "a_TexCoords"},
// 			{ShaderDataType::Float, "a_TexIndex"}
// 		);
// 
// 
// 		BufferLayout LineLayout(
// 			{
// 			{ShaderDataType::Float3, "a_Position", offsetof(LineVertex, Position)},
// 			{ShaderDataType::Float4, "a_Color", offsetof(LineVertex, Color)},
// 			},
// 
// 			sizeof(LineVertex)
// 			);
// 
// 
// 
// 		s_Storage.QuadVertexBuffer->SetLayout(QuadLayout);
// 		s_Storage.QuadVertexArray->AddVertexBuffer(s_Storage.QuadVertexBuffer);
// 
// 		s_Storage.LineVertexBuffer->SetLayout(LineLayout);
// 		s_Storage.LineVertexArray->AddVertexBuffer(s_Storage.LineVertexBuffer);
// 
// 		s_Storage.QuadVertexBufferBase = new QuadVertex[s_Storage.maxVerts];
// 
// 
// 		uint32_t* quadIndices = new uint32_t[s_Storage.maxIndices];
// 
// 		uint32_t offset = 0;
// 		for (uint32_t i = 0; i < s_Storage.maxIndices; i+=6)
// 		{
// 			quadIndices[i + 0] = offset + 0;
// 			quadIndices[i + 1] = offset + 1;
// 			quadIndices[i + 2] = offset + 2;
// 
// 			quadIndices[i + 3] = offset + 2;
// 			quadIndices[i + 4] = offset + 3;
// 			quadIndices[i + 5] = offset + 0;
// 
// 			offset += 4;
// 		}
// 
// 
// 		Ref<IndexBuffer> quadIB = IndexBuffer::Create(quadIndices, s_Storage.maxIndices);
// 		s_Storage.QuadVertexArray->SetIndexBuffer(quadIB);
// 		delete[] quadIndices;
// 
// 		s_Storage.WhiteTexture = Texture2D::Create(1, 1);
// 		uint32_t whiteTextureData = 0xffffffff;
// 		s_Storage.WhiteTexture->SetData(&whiteTextureData, sizeof(whiteTextureData));
// 
// 		int samplers[s_Storage.maxTextureSlots];
// 		for (int i = 0; i < 32; i++)
// 		{
// 			samplers[i] = i;
// 		}
// 
// 		s_Storage.TextureShader = Shader::Create("assets/shaders/texture.glsl");
// 		s_Storage.LineShader    = Shader::Create("Assets/Shaders/LineShader.glsl");
// 
// 		s_Storage.TextureShader->Bind();
// 		s_Storage.TextureShader->SetIntArray("u_Textures", samplers, s_Storage.maxTextureSlots);
// 
// 		s_Storage.TextureSlots[0] = s_Storage.WhiteTexture;
// 
// 
// 	}
// 
// 	void Renderer2D::StartBatch()
// 	{
// 		s_Storage.QuadVertexCount = 0;
// 		s_Storage.LineVertexCount = 0;
// 	}
// 
// 	void Renderer2D::Shutdown()
// 	{
// 		delete[] s_Storage.QuadVertexBufferBase;
// 		delete[] s_Storage.LineVertexBufferBase;
// 	}
// 
// 	void Renderer2D::QuadBeginScene(const OrthographicCamera& camera)
// 	{
// 		CN_PROFILE_FUNCTION();
// 
// 
// 		s_Storage.TextureShader->Bind();
// 		s_Storage.TextureShader->SetMat4("u_ViewProjection", camera.GetViewProjectionMatrix());
// 
// 
// 		s_Storage.QuadVertexBufferPtr = s_Storage.QuadVertexBufferBase;
// 
// 		StartBatch();
// 
// 	}
// 
// 	void Renderer2D::QuadEndScene()
// 	{
// 
// 		CN_PROFILE_FUNCTION();
// 
// 		FlushQuad();
// 	}
// 
// 	void Renderer2D::LineBeginScene(const OrthographicCamera& camera)
// 	{
// 		s_Storage.LineShader->Bind();
// 		s_Storage.LineShader->SetMat4("u_ProjectionView", camera.GetViewProjectionMatrix());
// 
// 		StartBatch();
// 	}
// 
// 	void Renderer2D::LineEndScene()
// 	{
// 		FlushLine();
// 	}
// 
// 
// 	void Renderer2D::FlushQuad()
// 	{
// 		// memory in bytes
// 		uint32_t dataSize = (uint8_t*)s_Storage.QuadVertexBufferPtr - (uint8_t*)s_Storage.QuadVertexBufferBase;
// 		s_Storage.QuadVertexBuffer->SetData(s_Storage.QuadVertexBufferBase, dataSize);
// 
// 		RenderCommand::DrawIndexed(s_Storage.QuadVertexArray);
// 	}
// 
// 	void Renderer2D::FlushLine()
// 	{
// 		uint32_t dataSize = (uint8_t*)s_Storage.LineVertexBufferPtr - (uint8_t*)s_Storage.LineVertexBufferBase;
// 
// 		s_Storage.LineVertexBuffer->SetData(s_Storage.LineVertexBufferBase, dataSize);
// 		uint32_t x = (2 * s_Storage.LineVertexCount) - 1;
// 		RenderCommand::DrawLine(*s_Storage.LineVertexArray, x);
// 		s_Storage.LineVertexCount = 0;
// 	}
// 
// 	void Renderer2D::NextBatch()
// 	{
// 		FlushQuad();
// 		StartBatch();
// 	}
// 
// 	void Renderer2D::DrawQuad(const glm::vec3& position, const glm::vec2& size, const glm::vec4& color, const float rotation)
// 	{
// 		CN_PROFILE_FUNCTION();
// 
// 		if (s_Storage.QuadVertexCount >= s_Storage.maxVerts)
// 			NextBatch();
// 
// 		uint32_t texIndex = 0;
// 
// 		s_Storage.QuadVertexBufferPtr->Position = ROTATE_POS(position, rotation);
// 		s_Storage.QuadVertexBufferPtr->Color = color;
// 		s_Storage.QuadVertexBufferPtr->TexCoord = { 0.0f, 0.0f };
// 		s_Storage.QuadVertexBufferPtr->TexIndex = texIndex;
// 		s_Storage.QuadVertexBufferPtr++;
// 
// 		s_Storage.QuadVertexBufferPtr->Position = ROTATE_POS( glm::vec3(position.x + size.x, position.y, 0.0f) , rotation);
// 		s_Storage.QuadVertexBufferPtr->Color = color;
// 		s_Storage.QuadVertexBufferPtr->TexCoord = { 1.0f, 0.0f };
// 		s_Storage.QuadVertexBufferPtr->TexIndex = texIndex;
// 		s_Storage.QuadVertexBufferPtr++;
// 
// 		s_Storage.QuadVertexBufferPtr->Position = ROTATE_POS( glm::vec3(position.x + size.x, position.y + size.y, 0.0f), rotation );
// 		s_Storage.QuadVertexBufferPtr->Color = color;
// 		s_Storage.QuadVertexBufferPtr->TexCoord = { 1.0f, 1.0f };
// 		s_Storage.QuadVertexBufferPtr->TexIndex = texIndex;
// 		s_Storage.QuadVertexBufferPtr++;
// 
// 		s_Storage.QuadVertexBufferPtr->Position = ROTATE_POS(glm::vec3(position.x, position.y + size.y, 0.0f), rotation);
// 		s_Storage.QuadVertexBufferPtr->Color = color;
// 		s_Storage.QuadVertexBufferPtr->TexCoord = { 0.0f, 1.0f };
// 		s_Storage.QuadVertexBufferPtr->TexIndex = texIndex;
// 		s_Storage.QuadVertexBufferPtr++;
// 
// 		s_Storage.QuadIndexCount += 6;
// 		s_Storage.QuadVertexCount += 4;
// 
// 		s_Storage.WhiteTexture->Bind();
// 
// #if 0
// 		s_Storage.WhiteTexture->Bind();
// 		s_Storage.TextureShader->SetFloat4("u_Color", color);
// 
// 
// 		glm::mat4 transform = glm::Mul(glm::Translation(glm::mat4(1.0f), position),
// 			(glm::Scale(glm::mat4(1.0f), glm::vec3{ size.x,size.y,1.0f })
// 		));
// 
// 		s_Storage.TextureShader->SetMat4("u_Transform", transform);
// 		s_Storage.QuadVertexArray->Bind();
// 		RenderCommand::DrawIndexed(s_Storage.QuadVertexArray);
// 
// #endif
// 	}
// 
// 
// 
// 	void Renderer2D::DrawQuad(const glm::vec3& position, const glm::vec2& size, const Ref<Texture2D>& texture, uint32_t index, const float rotation)
// 	{
// 
// 		CN_PROFILE_FUNCTION();
// 
// // 		float textureIndex = 0.0f;
// // 
// // 		for (uint32_t i = 1; i < s_Storage.TextureSlotIndex; i++)
// // 		{
// // 			if (*s_Storage.TextureSlots[i].get() == *texture.get())
// // 			{
// // 				textureIndex = (float)i;
// // 				break;
// // 			}
// // 		}
// // 
// // 		if (textureIndex == 0.0f)
// // 		{
// // 			textureIndex = (float)s_Storage.TextureSlotIndex;
// // 			s_Storage.TextureSlots[s_Storage.TextureSlotIndex] = texture;
// // 			s_Storage.TextureSlotIndex++;
// // 		}
// 
// 
// 		const glm::vec4 color(1.0f, 1.0f, 1.0f, 1.0f);
// 
// 
// 		if (s_Storage.QuadVertexCount >= s_Storage.maxVerts)
// 			NextBatch();
// 
// 
// 		s_Storage.QuadVertexBufferPtr->Position = ROTATE_POS(position, rotation);
// 		s_Storage.QuadVertexBufferPtr->Color = color;
// 		s_Storage.QuadVertexBufferPtr->TexCoord = { 0.0f, 0.0f };
// 		s_Storage.QuadVertexBufferPtr->TexIndex = index;
// 		s_Storage.QuadVertexBufferPtr++;
// 
// 		s_Storage.QuadVertexBufferPtr->Position = ROTATE_POS(glm::vec3(position.x + size.x, position.y, 0.0f), rotation);
// 		s_Storage.QuadVertexBufferPtr->Color = color;
// 		s_Storage.QuadVertexBufferPtr->TexCoord = { 1.0f, 0.0f };
// 		s_Storage.QuadVertexBufferPtr->TexIndex = index;
// 		s_Storage.QuadVertexBufferPtr++;
// 
// 		s_Storage.QuadVertexBufferPtr->Position = ROTATE_POS(glm::vec3(position.x + size.x, position.y + size.y, 0.0f), rotation);
// 		s_Storage.QuadVertexBufferPtr->Color = color;
// 		s_Storage.QuadVertexBufferPtr->TexCoord = { 1.0f, 1.0f };
// 		s_Storage.QuadVertexBufferPtr->TexIndex = index;
// 		s_Storage.QuadVertexBufferPtr++;
// 
// 		s_Storage.QuadVertexBufferPtr->Position = ROTATE_POS(glm::vec3(position.x, position.y + size.y, 0.0f), rotation);
// 		s_Storage.QuadVertexBufferPtr->Color = color;
// 		s_Storage.QuadVertexBufferPtr->TexCoord = { 0.0f, 1.0f };
// 		s_Storage.QuadVertexBufferPtr->TexIndex = index;
// 		s_Storage.QuadVertexBufferPtr++;
// 
// 		s_Storage.QuadIndexCount += 6;
// 		s_Storage.QuadVertexCount += 4;
// 
// 		texture->Bind(index);
// 
// #if 0
// 		s_Storage.TextureShader->SetFloat4("u_Color", { 1.0f,1.0f,1.0f,1.0f });
// 
// 
// 		texture->Bind();
// 
// 		glm::mat4 transform = glm::Mul(glm::Translation(glm::mat4(1.0f), position),
// 			glm::Scale(glm::mat4(1.0f), glm::vec3{ size.x, size.y, 1.0f }));
// 
// 
// 		s_Storage.TextureShader->SetMat4("u_Transform", transform);
// 
// 
// 		s_Storage.TextureShader->SetMat4("u_Transform", transform);
// 		s_Storage.QuadVertexArray->Bind();
// 		RenderCommand::DrawIndexed(s_Storage.QuadVertexArray);
// 
// #endif
// 	}
// 
// 	void Renderer2D::DrawQuad(const glm::mat4& transform, const glm::vec4& color, Ref<Texture2D> texture)
// 	{
// 		if (s_Storage.QuadVertexCount >= s_Storage.maxVerts)
// 			NextBatch();
// 
// 		uint32_t texIndex = 0;
// 		if (texture.get() == nullptr) 
// 			texture = s_Storage.WhiteTexture; //if the texture is null then bind the white texture to slot 0
// 		
// 		else
// 			texIndex = 1; // temporary
// 
// 
// 
// 		s_Storage.QuadVertexBufferPtr->Position = glm::Mul(transform, glm::vec3(0.0f, 0.0f, 0.0f));
// 		s_Storage.QuadVertexBufferPtr->Color = color;
// 		s_Storage.QuadVertexBufferPtr->TexCoord = { 0.0f, 0.0f };
// 		s_Storage.QuadVertexBufferPtr->TexIndex = texIndex;
// 		s_Storage.QuadVertexBufferPtr++;
// 
// 		s_Storage.QuadVertexBufferPtr->Position = glm::Mul(transform, glm::vec3(0.0f, 1.0f, 0.0f));
// 		s_Storage.QuadVertexBufferPtr->Color = color;
// 		s_Storage.QuadVertexBufferPtr->TexCoord = { 1.0f, 0.0f };
// 		s_Storage.QuadVertexBufferPtr->TexIndex = texIndex;
// 		s_Storage.QuadVertexBufferPtr++;
// 
// 		s_Storage.QuadVertexBufferPtr->Position = glm::Mul(transform, glm::vec3(1.0f, 1.0f, 0.0f));
// 		s_Storage.QuadVertexBufferPtr->Color = color;
// 		s_Storage.QuadVertexBufferPtr->TexCoord = { 1.0f, 1.0f };
// 		s_Storage.QuadVertexBufferPtr->TexIndex = texIndex;
// 		s_Storage.QuadVertexBufferPtr++;
// 
// 		s_Storage.QuadVertexBufferPtr->Position = glm::Mul(transform, glm::vec3(0.0f, 1.0f, 0.0f));
// 		s_Storage.QuadVertexBufferPtr->Color = color;
// 		s_Storage.QuadVertexBufferPtr->TexCoord = { 0.0f, 1.0f };
// 		s_Storage.QuadVertexBufferPtr->TexIndex = texIndex;
// 		s_Storage.QuadVertexBufferPtr++;
// 
// 		s_Storage.QuadIndexCount += 6;
// 		s_Storage.QuadVertexCount += 4;
// 
// 		if(texIndex)
// 			texture->Bind(texIndex);
// 		else
// 			s_Storage.WhiteTexture->Bind(0);
// 
// 
// 	}
// 
// 
// 
// 	void Renderer2D::DrawSubTexturedQuad(const glm::vec3& position, const glm::vec2& size, Ref<SubTexture2D> texture, unsigned int index, const float rotation)
// 	{
// 		if (s_Storage.QuadVertexCount >= s_Storage.maxVerts)
// 			NextBatch();
// 
// 		const glm::vec4 color(1.0f, 1.0f, 1.0f, 1.0f);
// 
// 
// 		s_Storage.QuadVertexBufferPtr->Position = ROTATE_POS(position, rotation);
// 		s_Storage.QuadVertexBufferPtr->Color = color;
// 		s_Storage.QuadVertexBufferPtr->TexCoord = texture->m_TextureCoordinate[0];
// 		s_Storage.QuadVertexBufferPtr->TexIndex = index;
// 		s_Storage.QuadVertexBufferPtr++;
// 
// 		s_Storage.QuadVertexBufferPtr->Position = ROTATE_POS(glm::vec3(position.x + size.x, position.y, 0.0f), rotation);
// 		s_Storage.QuadVertexBufferPtr->Color = color;
// 		s_Storage.QuadVertexBufferPtr->TexCoord = texture->m_TextureCoordinate[1];
// 		s_Storage.QuadVertexBufferPtr->TexIndex = index;
// 		s_Storage.QuadVertexBufferPtr++;
// 
// 		s_Storage.QuadVertexBufferPtr->Position = ROTATE_POS(glm::vec3(position.x + size.x, position.y + size.y, 0.0f), rotation);
// 		s_Storage.QuadVertexBufferPtr->Color = color;
// 		s_Storage.QuadVertexBufferPtr->TexCoord = texture->m_TextureCoordinate[2];
// 		s_Storage.QuadVertexBufferPtr->TexIndex = index;
// 		s_Storage.QuadVertexBufferPtr++;
// 
// 		s_Storage.QuadVertexBufferPtr->Position = ROTATE_POS(glm::vec3(position.x, position.y + size.y, 0.0f), rotation);
// 		s_Storage.QuadVertexBufferPtr->Color = color;
// 		s_Storage.QuadVertexBufferPtr->TexCoord = texture->m_TextureCoordinate[3];
// 		s_Storage.QuadVertexBufferPtr->TexIndex = index;
// 		s_Storage.QuadVertexBufferPtr++;
// 
// 		s_Storage.QuadIndexCount += 6;
// 		s_Storage.QuadVertexCount += 4;
// 
// 
// 		texture->RootTexture->Bind(index);
// 
// 	}
// 	void Renderer2D::DrawLine(const glm::vec3& positionA, const glm::vec3& positionB, const glm::vec4& color, const float& width)
// 	{
// 		if (s_Storage.LineVertexCount >= s_Storage.maxQuads)
// 		{
// 			FlushLine();
// 			StartBatch();
// 		}
// 
// 		// 		LineVertex(const glm::vec3& pos, const glm::vec4& color)
// 		
// 		s_Storage.LineVertexBufferPtr->Position = positionA;
// 		s_Storage.LineVertexBufferPtr->Color = color;
// 		s_Storage.LineVertexBufferPtr++;
// 
// 		s_Storage.LineVertexBufferPtr->Position = positionB;
// 		s_Storage.LineVertexBufferPtr->Color = color;
// 		s_Storage.LineVertexBufferPtr++;
// 
// 		s_Storage.LineVertexCount += 2;
// 		s_Storage.LineIndexCount += 2;
// 
// 		glLineWidth(width);
// 		//glColor4f(0, 1, 0, 1);
// 	}
// 
// 	void Renderer2D::DrawCurve(const glm::vec2& p0, const glm::vec2& p1, const glm::vec2& v0, const glm::vec2& v1, const glm::vec4& color, float width)
// 	{
// 		//hermite curve implementation best for joining points in a smooth manner
// 		glm::vec2 p;
// 		glm::vec3 tmp = glm::vec3(p0.x, p0.y, 0.0f);
// 
// 		for (int i = 1; i <= 10; i++)//iterating the value of t
// 		{
// 			float t = (float)i / 10.0;
// 			p.x = p0.x +
// 				t * v0.x +
// 				t * t * (-3 * p0.x - 2 * v0.x + 3 * p1.x - v1.x) +
// 				t * t * t * (2 * p0.x + v0.x - 2 * p1.x + v1.x);
// 			p.y = p0.y +
// 				t * v0.y +
// 				t * t * (-3 * p0.y - 2 * v0.y + 3 * p1.y - v1.y) +
// 				t * t * t * (2 * p0.y + v0.y - 2 * p1.y + v1.y);
// 			Renderer2D::DrawLine(tmp, glm::vec3(p.x, p.y, 0.0f), color, width);
// 			tmp = glm::vec3(p.x,p.y, 0.0f);
// 		}
// 
// 	}
// 	void Renderer2D::Draw_Bezier_Curve(const glm::vec2& p0, const glm::vec2& p1, const glm::vec2& p2, const glm::vec2& p3)
// 	{
// 
// 		glm::vec2 p;
// 		glm::vec3 tmp = glm::vec3(p.x, p.y, 0.0f);
// 
// 		for (int i = 1; i <= 10; i++)//iterating the value of t
// 		{
// 			float t = (float)i / 10.0;
// 			p.x = p0.x +
// 				t * (-3 * p0.x + 3 * p1.x) +
// 				t * t * (3 * p0.x - 6 * p1.x + 3 * p2.x) +
// 				t * t * t * (-p0.x + 3 * p1.x - 3 * p2.x + p3.x);
// 			p.y = p0.y +
// 				t * (-3 * p0.y + 3 * p1.y) +
// 				t * t * (3 * p0.y - 6 * p1.y + 3 * p2.y) +
// 				t * t * t * (-p0.y + 3 * p1.y - 3 * p2.y + p3.y);
// 			Renderer2D::DrawLine(tmp, glm::vec3(p.x, p.y, 0.0f), { 0.9,0.4,0.6,1 });
// 			tmp = glm::vec3(p.x, p.y, 0.0f);
// 		}
// 	}
// 
// 
// }