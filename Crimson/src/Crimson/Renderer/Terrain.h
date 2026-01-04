#include "Crimson.h"
#include "Water.h"
#include "Bloom.h"
#include "FrameBuffer.h"

namespace Crimson
{
	class Foliage;
	class QuadTree;
	class QNode;

	struct TerrainData
	{
		TerrainData() = default;
		glm::vec3 Position;
		glm::vec2 TexCoord;
	};



	class Terrain 
	{

		friend class QuadTree;

	public:

		Terrain() {}
		Terrain(float width, float height);
		~Terrain();

		void InitilizeTerrain();
		glm::vec3 player_camera_pos;
		static float WaterLevel, HillLevel, MountainLevel ,HeightScale , FoliageHeight;
		static bool bShowTerrain, bShowWireframeTerrain;
		static int maxGrassAmount, ChunkIndex, RadiusOfSpawn, GrassDensity;
		static glm::mat4 m_terrainModelMat;
		static std::vector<TerrainData> terrainData;
		static Ref<VertexArray> m_terrainVertexArray;
		Ref<Shader> m_terrainShader,m_terrainWireframeShader;
		static float time;

	public:
		inline float GetWaterHeight() const { return m_Water->GetHeight(); }
		inline void BindWaterReflectionFBO() const { m_Water->BindReflectionFBO(); }
		inline void UnBindWaterReflectionFBO() const { m_Water->UnbindReflectionFBO(); }
		inline void BindWaterRefractionFBO() const { m_Water->BindRefractionFBO(); }
		inline void UnBindWaterRefractionFBO() const { m_Water->UnbindRefractionFBO(); }

		inline PlatformGPUHandle GetWaterReflectionTexture() const { return m_Water->GetReflectionTextureHandle().ToPlatform(); }
		inline const FrameBufferSpecification& GetWaterReflectionSpec() const { return m_Water->GetReflectionSpec(); }
		
		inline PlatformGPUHandle GetWaterRefractionTexture() const { return m_Water->GetRefractionTextureHandle().ToPlatform(); }
		inline const FrameBufferSpecification& GetWaterRefractionSpec() const { return m_Water->GetRefractionSpec(); }

		void RenderTerrain(Camera& cam, bool withWater);
		void RenderWater(Camera& cam);
		void SetWaterFBOs(Bloom* bloom);

	private:

		QNode* m_RootNode = nullptr;
		Ref<QuadTree> m_Qtree;
		glm::vec2 m_Dimension;
		Ref<BufferLayout> m_BufferLayout;
		Ref<Texture2D> m_HeightMap, m_perlinNoise;
		Ref<Texture2DArray> TerrainTex_Albedo, TerrainTex_Roughness, TerratinTex_Normal;
		Ref<Texture2DArray> TerrainTex_Masks;
		int m_Height, m_Width, m_Channels,m_Channels1;
		float m_maxTerrainHeight; 
		float max_height;
		float min_height; 
		unsigned short* Height_data,*GrassSpawnArea;
		std::chrono::steady_clock::time_point StartTime;
		int CurrentChunkIndex = -1;
		float ChunkSize = 128.0f;	// to put in a util file - should be const 
		uint32_t foliageBufferIndex;



	private:
		uint32_t frame_counter = 0;
		Ref<Foliage> grass,grass2, grass3,
			Tree1,Tree2,Tree3,Tree4,Tree5,
			Bush1, Bush2, rock1, rock2, GroundPlant, Fern, flower1, flower2;
		std::vector<Ref<Foliage>> topFoliageLayer;
		std::vector<Ref<Foliage>> middleFoliageLayer;
		std::vector<Ref<Foliage>> bottomFoliageLayer;
		Ref<Water> m_Water;


		int GetChunkIndex(int PosX,int PosZ);
	};




	struct QNode //quad tree node
	{
		Bounds chunk_bounds;
		std::vector<QNode*> childrens;

		QNode() {}
		QNode(Bounds bounds)
		{
			chunk_bounds = bounds;
		}
		~QNode();

	};

	struct NodePool
	{
		static std::stack<QNode*> node_memoryPool;
		static QNode* GetNode(Bounds bounds);
		static void RecycleMemory(QNode*& node);
		static bool Allocate();
		static void DeAllocate();

		static float allocTime;

	};






	class QuadTree
	{
	public:
		QuadTree(Terrain* _terrain);
		void SpawnFoliageAtTile(QNode*& node, Camera& cam);
		void CreateChildren(QNode*& node, Camera& cam);
		void Insert(QNode*& node, Camera& cam);
		//this version returns all the leaf nodes
		void GetChildren(QNode*& node, std::vector<QNode*>& childrens);
		//function deletes every node at certain distance from player and also nodes which are not in view wrt player
		void DeleteNodesIfNotInScope(QNode* node, Camera& cam);
	private:
		// recursively delete nodes ,layerIDs define the startIndex and endIndex of foliage positions at 3 different layers(startID = layerIDs[n].x, endID = layerIDs[n].y)
		void DeleteNode(QNode*&);
		//check the intersection between 2 aabb
		bool aabbIntersection(Bounds& box1, Bounds& box2);
	private:
		Terrain* terrain;
	};
}