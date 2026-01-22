#pragma once

#include "Crimson.h"

namespace Crimson
{
	class BVH
	{
	public:
		
		enum SplitMethod
        {
            SAH, 
			MEAN
        };

		struct RTTriangle
		{
			glm::vec3 v0, v1, v2;
			glm::vec3 n0, n1, n2;
			glm::vec2 uv0, uv1, uv2;
			uint64_t TexAlbedo; //handle value for bindless albedo texture
			uint64_t TexRoughness; //handle value for bindless roughness texture
			uint32_t MaterialID;

			RTTriangle(glm::vec3& v0, glm::vec3& v1, glm::vec3& v2, glm::vec3& n0, glm::vec3& n1, glm::vec3& n2,
				glm::vec2& uv0, glm::vec2& uv1, glm::vec2& uv2, uint32_t materialID)
				: v0(v0), v1(v1), v2(v2), 
				  n0(n0), n1(n1), n2(n2), 
				  uv0(uv0), uv1(uv1), uv2(uv2), 
				  MaterialID(materialID),
				  TexAlbedo(0), TexRoughness(0)
			{
			}

			glm::vec3 GetCentroid() const { return (v0 + v1 + v2) * 0.3333333333333f; };
			Bounds GetBounds() { return Bounds(v0, v1, v2); };
		};

		struct BVHNode
		{
			BVHNode* LeftChild, * RightChild;
			int Axis;
			uint32_t TriangleStartID, TriangleCount;
			glm::vec3 aabbMin, aabbMax;//bounds of the node

			BVHNode() 
				:  LeftChild(nullptr), RightChild(nullptr), TriangleStartID(0), TriangleCount(0),
				   aabbMin(0.0f,0.0f,0.0f), aabbMax(0.0f,0.0f,0.0f)
			{
			}
		};

		struct LinearBVHNode
		{
			uint32_t RightChild;
			uint32_t TriangleStartID, TriangleCount;
			glm::vec3 aabbMin, aabbMax;

			LinearBVHNode() = default;
		};

		struct Bins
		{
			Bounds bounds;
			uint32_t TriangleCount = 0;

			Bins() = default;
		};

		struct Material
		{
			glm::vec4 Color;
			float Roughness;
			float Metalness;
			glm::vec4 EmissiveCol;
			float EmmisiveStrength;

			Material() = default;
		};

	public:
		BVH() = default;
		BVH(LoadMesh*& mesh);
		~BVH();
		void UpdateMaterials();

	private:
		void DestroyBVH(BVHNode*&);
		void BuildBVH(BVHNode*& node, uint32_t triStartID, uint32_t triCount);
		void CreateTriangles(const glm::mat4& transform = glm::mat4(1.0f)); //create triangles from mesh vertex positions
		void GenerateIndices();
		float EvaluateSAH(BVHNode& node, int& axis, float& pos); //returns cost after finding best axis and position
		int FlattenBVH(BVHNode* node, uint32_t* offset);
		void CleanBVH(BVHNode*& node);//removes count of triangles from child nodes

	public:
		std::vector<Material>& GetMaterials() { return m_Materials; }
		std::vector<LinearBVHNode>& GetLinearBVHNodes() { return m_LinearBVHNodes; }
		std::vector<RTTriangle>& GetRTTriangles() { return m_RTTriangles; }
		std::vector<uint32_t>& GetTriangleIndices() { return m_TriIndices; }
		
		// need make these private - todo . to fix
		std::vector<Material> m_Materials;
		std::vector<Ref<Texture2D>> m_AlbedoTextures;
		std::vector<Ref<Texture2D>> m_RoughnessTextures;

		std::vector<LinearBVHNode> m_LinearBVHNodes; //to be sent on to the gpu
		std::vector<RTTriangle> m_RTTriangles; //to be sent on to the gpu
		std::vector<uint32_t> m_TriIndices; //to be sent on to the gpu
		
		uint32_t m_NumNodes = 0;

	private:

		// will be used to store all indices processed, there will be a delimeter in the indices to determine the end
		// delimeter is -1 , indice cant be negative that why i use int64
		// indices of a certain mesh, after the vector will be cleared to free useless memory
		std::vector<int64_t> m_TempIndices;

		LoadMesh* m_Mesh = nullptr;
		BVHNode* m_Head = nullptr;
	};
}

