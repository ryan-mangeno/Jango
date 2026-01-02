#include "cnpch.h"
#include "BVH.h"
#include "Crimson/Core/Core.h"
#include "Crimson/Core/ResourceManager.h"
#include "Crimson/Renderer/GPUHandle.h"

#include <GLFW/glfw3.h>
#include <glad/glad.h>


constexpr uint32_t NUM_BINS = 200;


namespace Crimson
{
	static int val = 0;
	BVH::BVH(LoadMesh*& mesh)
		: m_Mesh(mesh), m_NumNodes(0)
	{

		CN_PROFILE_FUNCTION()

		uint32_t rootIndex = 0;
		const glm::mat4 transform = glm::rotate(glm::mat4(1.0f), glm::radians(180.0f), { 0.f,0.f,1.f }) * glm::scale(glm::mat4(1.0f), glm::vec3(0.1f));

		CN_CORE_TRACE("Creating Triangles : BVH")
		CreateTriangles(transform);
		CN_CORE_TRACE("Created Triangles ... Updating Materials : BVH")
		UpdateMaterials();
		CN_CORE_TRACE("Updated Materials : BVH")
		m_TriIndices.resize(m_RTTriangles.size());
		GenerateIndices();

		m_LinearBVHNodes.resize(m_LinearBVHNodes.size() * 2 + 1);
		CN_CORE_TRACE("BVH Creation started")
		BuildBVH(m_Head, 0, m_RTTriangles.size());
		CleanBVH(m_Head); //identify child nodes by making their triangle count = 0
		FlattenBVH(m_Head, &m_NumNodes);
		m_LinearBVHNodes.resize(m_NumNodes);

		CN_CORE_INFO("BVH Initialized!")

		CN_CORE_TRACE("Number of from BVH construction: {0}", m_RTTriangles.size());
	}

	BVH::~BVH()
	{
		DestroyBVH(m_Head);
	}

	void BVH::DestroyBVH(BVHNode*& node)
	{
		CN_PROFILE_FUNCTION()
		
		if (node == nullptr)
		{
				return;
		}

		if (node->LeftChild == nullptr && node->RightChild == nullptr)
		{
			delete node;
			node = nullptr;
			return;
		}
		else
		{
			node->TriangleCount = 0;
			if (node->LeftChild)
				CleanBVH(node->LeftChild);
			if (node->RightChild)
				CleanBVH(node->RightChild);
		}
	}


	void BVH::GenerateIndices()
	{ 
		uint32_t offsetIndex = 0; 
		uint32_t accumulatedIndices = 0;
		// there is some overhead from the delimeters but it will not be much, if I wanted to
		// I can track the number of delimeters added and allocate accordingly but as of now will not change
		m_TriIndices.reserve(m_TempIndices.size());

		for(uint32_t i = 0 ; i < m_TempIndices.size(); i++)
		{
			// if we are at delimeter
			if(m_TempIndices[i] == -1)
			{
				offsetIndex = accumulatedIndices;
			}
			else
			{
				m_TriIndices.push_back(m_TempIndices[i] + offsetIndex);
				// size is based off of the num of indices, not the delimeters
				accumulatedIndices++;
			}
		}
	}

	void BVH::CreateTriangles(const glm::mat4& transform)
	{

		CN_PROFILE_FUNCTION()

		uint32_t matCount = 0;
		std::vector<std::string> AlbedoPaths, RoughnessPaths; 
		for (const auto& sub_mesh : m_Mesh->GetSubMeshes())
		{
			Ref<Texture2D> AlbedoTexture = Texture2D::Create(ResourceManager::allMaterials[sub_mesh.MaterialID]->GetAlbedoPath());
			Ref<Texture2D> RoughnessTexture = Texture2D::Create(ResourceManager::allMaterials[sub_mesh.MaterialID]->GetRoughnessPath());

			//Enabling bindless textures causes render-doc to crash so disable them
			uint64_t AlbedoHandle = glGetTextureHandleARB(0/*AlbedoTexture->GetHandle().ToPlatform()*/); //get a handle from the gpu to fix / todo

			glMakeTextureHandleResidentARB(AlbedoHandle); //load the texture into gpu memory using the handle
			uint64_t RoughnessHandle = glGetTextureHandleARB(0/*RoughnessTexture->GetHandle().ToPlatform()*/); // to fix / todo
			if(AlbedoHandle!=RoughnessHandle)
			{
				glMakeTextureHandleResidentARB(RoughnessHandle);
			}
			// to fix, triangulating model on import, getting weird artifacts when i do, but this works without triangulation
			// could be due to how im rendering the models
			// however, since are tringulating, we have numfaces * 3, numfaces is some positive integer, so 3 | numfaces * 3
			// we can index by step of 3 safely
			for (uint32_t i = 0; i < sub_mesh.Indices.size(); i += 3)
			{

				const uint32_t idx0 = sub_mesh.Indices[i];
				const uint32_t idx1 = sub_mesh.Indices[i + 1];
				const uint32_t idx2 = sub_mesh.Indices[i + 2];

				//transforming the vertices and normals to world space
				glm::vec3 v0 = transform * glm::vec4(sub_mesh.Vertices[idx0], 1.0f);
				glm::vec3 v1 = transform * glm::vec4(sub_mesh.Vertices[idx1], 1.0f);
				glm::vec3 v2 = transform * glm::vec4(sub_mesh.Vertices[idx2], 1.0f);

				glm::mat3 normalMatrix = glm::transpose(glm::inverse(glm::mat3(transform)));
				glm::vec3 n0 = normalMatrix * sub_mesh.Normal[idx0];
				glm::vec3 n1 = normalMatrix * sub_mesh.Normal[idx1];
				glm::vec3 n2 = normalMatrix * sub_mesh.Normal[idx2];

				//glm::vec3 n0 = transform * glm::vec4(sub_mesh.Normal[idx0], 1.0f);
				//glm::vec3 n1 = transform * glm::vec4(sub_mesh.Normal[idx1], 1.0f);
				//glm::vec3 n2 = transform * glm::vec4(sub_mesh.Normal[idx2], 1.0f);

				glm::vec2 uv0 = sub_mesh.TexCoord[idx0];
				glm::vec2 uv1 = sub_mesh.TexCoord[idx1];
				glm::vec2 uv2 = sub_mesh.TexCoord[idx2];

				RTTriangle triangle(v0, v1, v2, n0, n1, n2, uv0, uv1, uv2, matCount);
				triangle.TexAlbedo = AlbedoHandle;
				triangle.TexRoughness = RoughnessHandle;

				m_RTTriangles.push_back(triangle);

				m_TempIndices.push_back(idx0);
				m_TempIndices.push_back(idx1);
				m_TempIndices.push_back(idx2);
			}

			// adding delimeter for the end of a mesh's vertices/indices
			m_TempIndices.push_back(-1);

			matCount++; //increment the material as we move to the next sub mesh

			CN_CORE_TRACE("Made Material");
		}
		m_Materials.resize(matCount);
		
	}

	void BVH::UpdateMaterials()
	{

		CN_PROFILE_FUNCTION()

		int k = 0;
		for (auto& sub_mesh : m_Mesh->GetSubMeshes()) 
		{
			CN_CORE_TRACE("Updating Material, Count : {0}", k);
			CN_ASSERT(ResourceManager::allMaterials[sub_mesh.MaterialID], "Resource Manager Invalid (BVH)");
			auto& ResourceMaterial = ResourceManager::allMaterials[sub_mesh.MaterialID];
			Material mat;
			mat.Color = ResourceMaterial->GetColor();
			mat.EmissiveCol = ResourceMaterial->GetColor(); //needs change
			mat.EmmisiveStrength = ResourceMaterial->GetEmission(); //needs change
			mat.Metalness = ResourceMaterial->GetMetalness();
			mat.Roughness = ResourceMaterial->GetRoughness();
			m_Materials[k] = mat;
			k++;
		}
	}

	float BVH::EvaluateSAH(BVHNode& node, int& axis, float& pos)
	{

		CN_PROFILE_FUNCTION()

		float best_cost = std::numeric_limits<float>::max();
		Bounds ResultingBound; //get the total bounds of all the triangles in a particular node
		for (int i = 0; i < node.TriangleCount; i++)
		{
			const Bounds& bnds = (m_RTTriangles[m_TriIndices[node.TriangleStartID + i]].GetBounds());

			// adding node bound to resulting bound
			ResultingBound.Union(bnds);
		}

		for (int a = 0; a < 3; a++) //iterate through all the axises
		{

			if (ResultingBound.aabbMax[a] == ResultingBound.aabbMin[a])
				continue;

			Bins bins[NUM_BINS]; //create bins array to store the triangle count and the bounds of the triangles in a node
			uint32_t size = (ResultingBound.aabbMax[a] - ResultingBound.aabbMin[a]) / NUM_BINS; //get size of individual bin
			for (int i = 0; i < node.TriangleCount; i++)
			{
				BVH::RTTriangle& triangle = m_RTTriangles[m_TriIndices[node.TriangleStartID + i]];
				//get the bin index
				uint32_t binIndx = std::min(NUM_BINS - 1, static_cast<uint32_t>(std::abs((triangle.GetCentroid()[a] - ResultingBound.aabbMin[a]) / static_cast<int>(size) )));
				bins[binIndx].TriangleCount++;
				bins[binIndx].bounds.Union(triangle.GetBounds());

			}

			// determine triangle counts and bounds for this split candidate
			Bounds leftBox, rightBox;
			int leftTriangleCount[NUM_BINS - 1], rightTriangleCount[NUM_BINS - 1]; //containers to store the total triangle count and area on left side of the split plane
			float leftSurfaceArea[NUM_BINS - 1], rightSurfaceArea[NUM_BINS - 1]; //containers to store the total triangle count and area on right side of the split plane
			int leftCount = 0, rightCount = 0;
			for (uint32_t i = 0; i < NUM_BINS - 1; i++) //accumulate the triangle count and box area.
			{
				leftCount += bins[i].TriangleCount;
				leftBox.Union(bins[i].bounds);
				leftTriangleCount[i] = leftCount;
				leftSurfaceArea[i] = leftBox.area(); //fill from first to last

				rightCount += bins[NUM_BINS - 1 - i].TriangleCount;
				rightBox.Union(bins[NUM_BINS - 1 - i].bounds);
				rightTriangleCount[NUM_BINS - 2 - i] = rightCount;
				rightSurfaceArea[NUM_BINS - 2 - i] = rightBox.area(); //fill from last to first
			}

			for (uint32_t i = 0; i < NUM_BINS - 1; i++) //evaluate cost using surface area heuristic
			{
				float cost = leftTriangleCount[i] * leftSurfaceArea[i] + rightTriangleCount[i] * rightSurfaceArea[i];
				if (cost < best_cost)
				{
					best_cost = cost;
					axis = a;
					pos = ResultingBound.aabbMin[a] + (i + 1) * size;
				}
			}
		}
		return best_cost > 0 ? best_cost : 1e30f;
	}

	int BVH::FlattenBVH(BVHNode* node, uint32_t* offset)//dfs traversal
	{

		CN_PROFILE_FUNCTION()

		LinearBVHNode* linearNode = &m_LinearBVHNodes[*offset];
		linearNode->aabbMax = node->aabbMax;
		linearNode->aabbMin = node->aabbMin;

		uint32_t myOffset = (*offset)++;

		if (node->TriangleCount > 0) 
		{
			// If the node has triangles, assign them to this node
			linearNode->TriangleStartID = node->TriangleStartID;
			linearNode->TriangleCount = node->TriangleCount;
		}

		else 
		{
			linearNode->TriangleStartID = node->TriangleStartID;
			linearNode->TriangleCount = node->TriangleCount;

			BVH::FlattenBVH(node->LeftChild, offset);
			linearNode->RightChild = BVH::FlattenBVH(node->RightChild, offset);
		}

		return myOffset;
	}

	void BVH::CleanBVH(BVHNode*& node)
	{

		CN_PROFILE_FUNCTION()

		if (node->LeftChild == nullptr && node->RightChild == nullptr)
		{
			return;
		}
		else
		{
			node->TriangleCount = 0;
			if (node->LeftChild)
				CleanBVH(node->LeftChild);
			if (node->RightChild)
				CleanBVH(node->RightChild);
		}
	}


	//recursively building the bvh tree and storing it as dfs format
	void BVH::BuildBVH(BVHNode*& node, uint32_t triStartID, uint32_t triCount)
	{

		CN_PROFILE_FUNCTION()

		node = new BVHNode();
		Bounds bounds;

		for (int i = 0; i < triCount; i++)
		{
			const Bounds& bnds = m_RTTriangles[m_TriIndices[i + triStartID]].GetBounds();
			bounds.Union(bnds);
		}

		node->aabbMax = bounds.aabbMax;
		node->aabbMin = bounds.aabbMin;
		node->TriangleStartID = triStartID;
		node->TriangleCount = triCount;

		int bestAxis = -1;
		float bestPos = 0, bestCost = 1e30f;

		bestCost = EvaluateSAH(*node, bestAxis, bestPos);

		node->Axis = bestAxis;//net the node axis
		if (triCount <= 2)//2 is the minimum number of triangles that a node should contain
		{
			return;
		}

		int axis = bestAxis;
		glm::vec3 extent = bounds.aabbMax - bounds.aabbMin;
		float splitPos = bestPos;

		float parentArea = extent.x * extent.y + extent.y * extent.z + extent.z * extent.x;
		float parentCost = triCount * parentArea;

		if (bestCost >= parentCost)
			return;

		int i = triStartID, j = i + triCount - 1;

		//do partial sorting
		while (i <= j)
		{
			if (m_RTTriangles[m_TriIndices[i]].GetCentroid()[axis] < splitPos)
			{
				i++;
			}
			else
			{
				std::swap(m_TriIndices[i], m_TriIndices[j--]);
			}
		}

		int leftCount = i - triStartID;
		if (leftCount == 0 || leftCount == triCount)
		{
			return;
		}
		BVH::BuildBVH(node->LeftChild, triStartID, leftCount);
		BVH::BuildBVH(node->RightChild, i, triCount - leftCount);
	}
}
