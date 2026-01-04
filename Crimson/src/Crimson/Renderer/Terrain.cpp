#include "cnpch.h"
#include "Crimson/Core/Log.h"
#include "Crimson/Renderer/FoliageRenderer.h"
#include "Terrain.h"
#include "glad/glad.h"
#include "stb_image.h"
#include "Crimson/Physics/Physics3D.h"
#include "Crimson/Renderer/Antialiasing.h"
#include "Crimson/Renderer/FrameBuffer.h"


//temporary
#include <GLFW/glfw3.h>

/*
	terrain class needs its own ui and modelling tools for basic prototyping.
	and also remove redundant glsl codes.
*/

namespace Crimson
{
	float Terrain::WaterLevel = 0.1, Terrain::HillLevel = 0.5, Terrain::MountainLevel = 1.0
		, Terrain::HeightScale = 200, Terrain::FoliageHeight = 6.0f;

	bool Terrain::bShowTerrain = true, Terrain::bShowWireframeTerrain = false;
	int Terrain::maxGrassAmount = 0, Terrain::ChunkIndex = 0, Terrain::RadiusOfSpawn = 1, Terrain::GrassDensity = 3;
	glm::mat4 Terrain::m_terrainModelMat;
	std::vector<TerrainData> Terrain::terrainData;
	Ref<VertexArray> Terrain::m_terrainVertexArray;
	float Terrain::time = 0;
	std::stack<QNode*> NodePool::node_memoryPool;

	Terrain::Terrain(float width, float height)
	{
		grass = MakeRef<Foliage>(Scene::Grass, 1024 * 80, 100, false, 50, false, true, true, 2,3, "Assets/Textures/ForestMask.png");
		grass2 = MakeRef<Foliage>(Scene::Grass2, 1024 * 70, 300, true, 80, false, true, true, 1, 3, "Assets/Textures/ValleyMask.png");
		grass3 = MakeRef<Foliage>(Scene::Grass3, 1024 * 70, 300, false, 200, false, true, true, 2, 3, "Assets/Textures/ValleyMask.png");
		flower1 = MakeRef<Foliage>(Scene::Flower1, 1024 * 70, 300, false, 100, false, true, true, 1, 3, "Assets/Textures/FlowerMask.png");
		flower2 = MakeRef<Foliage>(Scene::Flower2, 1024 * 70, 300, false, 100, false, true, true, 1, 3, "Assets/Textures/FlowerMask.png");

		Tree1 = MakeRef<Foliage>(Scene::Tree1, 1024 * 5, 800, true, 450, false, true, false, 2,3, "Assets/Textures/ForestMask.png");
		Tree2 = MakeRef<Foliage>(Scene::Tree2, 1024 * 5, 800, true, 450, false, true, false, 2,3, "Assets/Textures/Fern_Mask.png");
		Tree3 = MakeRef<Foliage>(Scene::Tree3, 1024 * 5, 800, true, 350, false, false, true, 2,3, "Assets/Textures/ValleyMask.png"); //dead tree
		Tree4 = MakeRef<Foliage>(Scene::Tree4, 1024 * 5, 800, true, 100, false, true, false, 2,3, "Assets/Textures/ForestMask.png");
		Tree5 = MakeRef<Foliage>(Scene::Tree5, 1024 * 5, 800, true, 400, false, true, false, 2,3, "Assets/Textures/FlowerMask.png");

		Bush1 = MakeRef<Foliage>(Scene::Bush1, 1024 * 15, 500, true, 30, false, true, false, 1,3, "Assets/Textures/ForestMask.png");
		Bush2 = MakeRef<Foliage>(Scene::Bush2, 1024 * 15, 500, true, 30, false, true, false, 1,3, "Assets/Textures/ForestMask.png");
		rock1 = MakeRef<Foliage>(Scene::Rock1, 1024 * 15, 800, true, 100, false, false, true, 2,3, "Assets/Textures/ForestMask.png");
		rock2 = MakeRef<Foliage>(Scene::Rock2, 1024 * 20, 800, true, 400, false, false, true, 2,3, "Assets/Textures/ValleyMask.png");

		GroundPlant = MakeRef<Foliage>(Scene::GroundPlant, 1024 * 80, 150, true, 100, false, true, true, 2, 3, "Assets/Textures/ForestMask.png");
		Fern = MakeRef<Foliage>(Scene::Fern, 1024 * 30, 200, true, 150, false, true, true, 1, 3, "Assets/Textures/Fern_Mask.png");

		//set distribution parameters on foliage
		Tree1->SetFoliageDistributionParam(30.0, 2, 1, 0.6);
		Tree4->SetFoliageDistributionParam(35.0, 10, 2, 0.4);
		Tree2->SetFoliageDistributionParam(30.0, 2, 1, 1.0);
		Tree3->SetFoliageDistributionParam(85.0, 1, 0.01, 1.0);
		Tree5->SetFoliageDistributionParam(130.0, 5, 2, 1.0);


		rock1->SetFoliageDistributionParam(15, 3, 1.0, 0.2);
		rock2->SetFoliageDistributionParam(25, 3, 1.0, 1.0);
		Bush1->SetFoliageDistributionParam(15, 0.3, 0.03, 0.2);
		Bush2->SetFoliageDistributionParam(15, 0.3, 0.03, 0.6);

		grass->SetFoliageDistributionParam(3.0, 0.3, 0.06, 0.3);
		GroundPlant->SetFoliageDistributionParam(4.0, 0.3, 0.08, 0.7);
		Fern->SetFoliageDistributionParam(6.0, 5, 1, 1.0);
		grass2->SetFoliageDistributionParam(4.0, 0.3, 0.06, 0.6);
		grass3->SetFoliageDistributionParam(8.0, 0.3, 0.06, 0.2);
		flower1->SetFoliageDistributionParam(4.0, 0.3, 0.06, 0.2);
		flower2->SetFoliageDistributionParam(4.0, 0.3, 0.06, 1.0);


		//top layer
		topFoliageLayer.push_back(Tree5);
		topFoliageLayer.push_back(Tree3);
		topFoliageLayer.push_back(Tree2);
		topFoliageLayer.push_back(Tree4);
		topFoliageLayer.push_back(Tree1);

		middleFoliageLayer.push_back(rock1);
		middleFoliageLayer.push_back(Bush1);
		middleFoliageLayer.push_back(Bush2);
		middleFoliageLayer.push_back(rock2);

		bottomFoliageLayer.push_back(Fern);
		bottomFoliageLayer.push_back(grass);
		bottomFoliageLayer.push_back(GroundPlant);
		bottomFoliageLayer.push_back(grass3);
		bottomFoliageLayer.push_back(flower1);
		bottomFoliageLayer.push_back(grass2);
		bottomFoliageLayer.push_back(flower2);


		maxGrassAmount = ChunkSize * ChunkSize * (pow(2 * RadiusOfSpawn + 1, 2));//radius of spawn defines how many tiles to cover from the centre
		StartTime = std::chrono::high_resolution_clock::now();
		m_Dimension.x = width;
		m_Dimension.y = height;
		m_maxTerrainHeight = std::numeric_limits<float>::min();
		m_terrainShader = Shader::Create("Crimson_Editor/Assets/Shaders/GLSL/Terrain.glsl");
		m_terrainWireframeShader = Shader::Create("Crimson_Editor/Assets/Shaders/GLSL/TerrainWireframe.glsl");


		m_Water = Water::Create({ width, 20.0f, width }, { 0.0f, 0.0f, 1.0f, 1.0f }, { 512, 512 });


		InitilizeTerrain();
	}
	Terrain::~Terrain()
	{

	}
	void Terrain::InitilizeTerrain()
	{
		stbi_set_flip_vertically_on_load(1);//need to abstract
		Height_data = stbi_load_16("Assets/Textures/heightmap.png", &m_Width, &m_Height, &m_Channels, 0);
		//needs to have different width,height,channels
		GrassSpawnArea = stbi_load_16("Assets/Textures/grass_mask.png", &m_Width, &m_Height, &m_Channels1, 0);

		m_HeightMap = Texture2D::Create("Assets/Textures/heightmap.png", true);
		m_perlinNoise = Texture2D::Create("Assets/Textures/PerlinTexture2.jpg");

		/*
			Terrain Layer Format:
			Layer0: Grass Texture; //base texture
			Layer1: Another Grass1; //masked texture
			Layer2: Another Grass2; //masked texture
			Layer3: Another Grass3; //masked texture

			Layer4: Cliff/Rock Texture //procedural maked textures(created/masked based on terrain data like slope);
		*/
		//get all textures for the terrain layers
		std::vector<std::string> albedo_paths = {"Assets/Textures/xiboddsr_1K_Albedo.jpg", "Assets/Textures/xiboab2r_2K_Albedo.jpg", "Assets/Textures/oeeb7_1K_Albedo.jpg", "Assets/Textures/xccibbi_2K_Albedo.jpg" };
		std::vector<std::string> roughness_paths = { "Assets/Textures/xiboddsr_1K_Roughness.jpg", "Assets/Textures/xiboab2r_2K_Roughness.jpg", "Assets/Textures/oeeb7_1K_Roughness.jpg", "Assets/Textures/xccibbi_2K_Roughness.jpg" };
		std::vector<std::string> normal_paths = {"Assets/Textures/xiboddsr_1K_Normal.jpg", "Assets/Textures/xiboab2r_2K_Normal.jpg", "Assets/Textures/oeeb7_1K_Normal.jpg", "Assets/Textures/xccibbi_2K_Normal.jpg"};
		std::vector<std::string> mask_paths = { "Assets/Textures/Fern_Mask.png", "Assets/Textures/ValleyMask.png"};

		TerrainTex_Albedo = Texture2DArray::Create(albedo_paths);
		TerrainTex_Roughness = Texture2DArray::Create(roughness_paths);
		TerratinTex_Normal = Texture2DArray::Create(normal_paths);

		TerrainTex_Masks = Texture2DArray::Create(mask_paths);
		//Renderer3D::AllocateInstancedFoliageData(maxGrassAmount * GrassDensity, foliageBufferIndex);

		m_terrainShader->Bind();
		m_HeightMap->Bind(HEIGHT_MAP_TEXTURE_SLOT);
		m_perlinNoise->Bind(PERLIN_NOISE_TEXTURE_SLOT);
		m_terrainShader->SetInt("u_HeightMap", HEIGHT_MAP_TEXTURE_SLOT);
		m_terrainShader->SetInt("u_Albedo", ALBEDO_SLOT);
		m_terrainShader->SetInt("u_Roughness", ROUGHNESS_SLOT);
		m_terrainShader->SetInt("u_Normal", NORMAL_SLOT);
		m_terrainShader->SetInt("u_Masks", TERRAIN_MASK_TEXTURE_SLOT);
		m_terrainShader->SetInt("u_perlinNoise", PERLIN_NOISE_TEXTURE_SLOT);
		m_terrainShader->SetInt("diffuse_env", IRR_ENV_SLOT);
		m_terrainShader->SetInt("specular_env", ENV_SLOT);
		m_terrainShader->SetInt("SSAO", SSAO_BLUR_SLOT);
		m_terrainWireframeShader->Bind();
		m_terrainWireframeShader->SetInt("u_HeightMap", HEIGHT_MAP_TEXTURE_SLOT);

		m_terrainVertexArray = VertexArray::Create();

		//divide the landscape in 'n' number of patches
		float res = ChunkSize;
		//skip the edges for abrupt triangle formation
		for (int i = 2; i <= m_Dimension.y - 2; i += res)
		{
			for (int j = 2; j <= m_Dimension.x - 2; j += res)
			{
				TerrainData v1;
				v1.Position = glm::vec3(j, 0, i);
				v1.TexCoord = glm::vec2(j / m_Dimension.x, i / m_Dimension.y);
				terrainData.push_back(v1);

				TerrainData v2;
				v2.Position = glm::vec3(j + res, 0, i);
				v2.TexCoord = glm::vec2(j / m_Dimension.x + res / m_Dimension.x, i / m_Dimension.y);
				terrainData.push_back(v2);

				TerrainData v3;
				v3.Position = glm::vec3(j, 0, i + res);
				v3.TexCoord = glm::vec2(j / m_Dimension.x, i / m_Dimension.y + res / m_Dimension.y);
				terrainData.push_back(v3);

				TerrainData v4;
				v4.Position = glm::vec3(j + res, 0, i + res);
				v4.TexCoord = glm::vec2(j / m_Dimension.x + res / m_Dimension.x, i / m_Dimension.y + res / m_Dimension.y);
				terrainData.push_back(v4);
			}
		}

		Ref<VertexBuffer> vb = VertexBuffer::Create(&terrainData[0].Position.x, sizeof(TerrainData) * terrainData.size());
		m_BufferLayout = MakeRef<BufferLayout>();
		m_BufferLayout->push("Position", ShaderDataType::Float3);
		m_BufferLayout->push("coord", ShaderDataType::Float2);
		m_terrainVertexArray->AddBuffer(m_BufferLayout, vb);
		glPatchParameteri(GL_PATCH_VERTICES, 4);//will be present after all vertex array operations for tessellation

		glm::mat4 terrain_transform = glm::mat4(1.0f);//glm::translate(glm::mat4(1.0f), { 0,0,0 }) * glm::rotate(glm::mat4(1.0), glm::radians(180.0f), { 0,0,1 });
		max_height = std::numeric_limits<float>::min();
		min_height = std::numeric_limits<float>::max();

		for (int j = 0; j < m_Width; j++)
		{
			for (int i = 0; i < m_Height; i++)
			{
				if (max_height < Height_data[j * m_Width + i + m_Channels])
					max_height = Height_data[j * m_Width + i + m_Channels];
			}
		}

		for (int j = 0; j < m_Width; j++)
		{
			for (int i = 0; i < m_Height; i++)
			{
				if (min_height > Height_data[j * m_Width + i + m_Channels])
					min_height = Height_data[j * m_Width + i + m_Channels];
			}
		}

		std::uniform_real_distribution<float> RandomFloat(-1.0f, 1.0f);
		std::normal_distribution<float> NormalDist(0.0f, 1.0f);
		std::default_random_engine generator;

		CurrentChunkIndex = 0;//Let cam position at start is at 0,0
		//SpawnGrassOnChunks(0, 0, RadiusOfSpawn);

		//Terrain collision
		std::vector<int> HeightValues;
		int spacing = 32;
		//in physx the data is stored in row-major format
		for (int j = 0; j < m_Width; j += spacing) {
			for (int i = 0; i < m_Height; i += spacing)
			{
				float y = (Height_data[i * m_Width + j + m_Channels] - min_height) / (max_height - min_height);//R channel of 1st vertex
				y *= HeightScale;

				HeightValues.push_back(ceil(y));
			}
		}
		//Physics3D::AddHeightFieldCollider(HeightValues, m_Width, m_Height, spacing, glm::mat4(1.0f));//transform is hard codded
		//stbi_image_free(Height_data);
	}



	void Terrain::RenderTerrain(Camera& cam, bool withWater)
	{
		
		++frame_counter;
		player_camera_pos = cam.GetCameraPosition();
		if (m_Qtree == nullptr)
			m_Qtree = MakeRef<QuadTree>(this);
		if (m_RootNode == nullptr)
			m_RootNode = NodePool::GetNode(Bounds(glm::vec3(0, 0, 0), glm::vec3(m_Dimension.x, 0, m_Dimension.y)));
		
		m_Qtree->Insert(m_RootNode, cam);
		if (frame_counter % 10 == 0) //check to delete after every 10th frame
			m_Qtree->DeleteNodesIfNotInScope(m_RootNode, cam);

		if (bShowTerrain) 
		{
			for (auto& topLayerFoliage : topFoliageLayer)
				topLayerFoliage->RenderFoliage(cam);
			for (auto& middleLayerFoliage : middleFoliageLayer)
				middleLayerFoliage->RenderFoliage(cam);
			for (auto& bottomLayerFoliage : bottomFoliageLayer)
				bottomLayerFoliage->RenderFoliage(cam);
		}

		int CamX = cam.GetCameraPosition().x;
		int CamZ = cam.GetCameraPosition().z;

		glEnable(GL_CULL_FACE);
		glCullFace(GL_FRONT);
		m_terrainModelMat = glm::mat4(1.0);

		TerrainTex_Albedo->Bind(ALBEDO_SLOT);
		TerrainTex_Roughness->Bind(ROUGHNESS_SLOT);
		TerratinTex_Normal->Bind(NORMAL_SLOT);
		TerrainTex_Masks->Bind(TERRAIN_MASK_TEXTURE_SLOT);

		m_terrainShader->Bind();
		m_terrainShader->SetFloat("u_Tiling", 30);//Tiling factor for all terrain textures (not for height map)
		m_terrainShader->SetFloat("HEIGHT_SCALE", HeightScale);
		m_terrainShader->SetFloat("FoliageHeight", FoliageHeight);
		m_terrainShader->SetFloat3("DirectionalLight_Direction", Renderer3D::m_SunLightDir);
		m_terrainShader->SetFloat3("SunLight_Color", Renderer3D::m_SunColor);
		m_terrainShader->SetFloat("SunLight_Intensity", Renderer3D::m_SunIntensity);
		m_terrainShader->SetFloat("u_Intensity", Renderer3D::m_SunIntensity);
		m_terrainShader->SetMat4("u_ProjectionView", cam.GetProjectionView());
		m_terrainShader->SetMat4("u_oldProjectionView", Renderer3D::m_oldProjectionView);
		m_terrainShader->SetMat4("u_Model", m_terrainModelMat);
		m_terrainShader->SetMat4("u_View", cam.GetViewMatrix());
		m_terrainShader->SetFloat3("camPos", cam.GetCameraPosition());
		m_terrainShader->SetFloat("WaterLevel", WaterLevel);
		m_terrainShader->SetFloat("HillLevel", HillLevel);
		m_terrainShader->SetFloat("MountainLevel", MountainLevel);
		time = std::chrono::duration_cast<std::chrono::milliseconds>(std::chrono::high_resolution_clock::now() - StartTime).count() / 1000.0;
		m_terrainShader->SetFloat("Time", time);



		if (bShowTerrain)
		{
			RenderCommand::DrawArrays(*m_terrainVertexArray, terrainData.size(), GL_PATCHES, 0);
		}

		if (bShowWireframeTerrain)
		{
			m_terrainWireframeShader->Bind();
			m_terrainWireframeShader->SetFloat("HEIGHT_SCALE", HeightScale);
			m_terrainWireframeShader->SetMat4("u_ProjectionView", cam.GetProjectionView());
			m_terrainWireframeShader->SetMat4("u_Model", m_terrainModelMat);
			m_terrainWireframeShader->SetMat4("u_View", cam.GetViewMatrix());
			m_terrainWireframeShader->SetFloat3("camPos", cam.GetCameraPosition());
			m_terrainWireframeShader->SetFloat("WaterLevel", WaterLevel);
			m_terrainWireframeShader->SetFloat("HillLevel", HillLevel);
			m_terrainWireframeShader->SetFloat("MountainLevel", MountainLevel);

			RenderCommand::DrawArrays(*m_terrainVertexArray, terrainData.size(), GL_PATCHES, 0);
		}

		// render water after since we change shaders
		if (withWater && bShowTerrain)
		{
			m_Water->RenderWater(cam, { 512,512 });
		}
		


		glEnable(GL_CULL_FACE);
		glCullFace(GL_BACK);
	}


	void Terrain::RenderWater(Camera& cam)
	{
		m_Water->RenderWater(cam, {512,512});
	}

	void Terrain::SetWaterFBOs(Bloom* bloom)
	{
		GLint previousViewport[4];
		glGetIntegerv(GL_VIEWPORT, previousViewport);

		const FrameBufferSpecification& water_spec = GetWaterReflectionSpec();
		glViewport(0, 0, water_spec.Width, water_spec.Height);

		BindWaterReflectionFBO();

		RenderCommand::ClearColor({ 0,0,0,1 });
		RenderCommand::Clear();
		bloom->RenderForFBO();

		UnBindWaterReflectionFBO();
		glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
		glViewport(previousViewport[0], previousViewport[1], previousViewport[2], previousViewport[3]);

	}

	QuadTree::QuadTree(Terrain* _terrain) : terrain(_terrain)
	{
		//delete_NodeThread = std::thread([&]() {DeleteNodesIfNotInScope(); });
		//delete_NodeThread.join();
	}

	void QuadTree::SpawnFoliageAtTile(QNode*& node, Camera& cam)
	{
		glm::vec3 mid_point = node->chunk_bounds.GetMidPoint();
		glm::vec3 bounds_min = node->chunk_bounds.aabbMin;
		glm::vec3 bounds_max = node->chunk_bounds.aabbMax;
		glm::vec3 chunk_size = bounds_max - bounds_min;

		if (chunk_size.x == 256)
		{
			//load the top level of foliage
			for (auto& topPlant : terrain->topFoliageLayer)
			{
				topPlant->bHasSpawnned = false;
				topPlant->GenerateFoliagePositions(node->chunk_bounds);
			}
		}
		if (chunk_size.x == 128)
		{
			//load the middle level of foliage
			for (auto& middlePlant : terrain->middleFoliageLayer)
			{
				middlePlant->bHasSpawnned = false;
				middlePlant->GenerateFoliagePositions(node->chunk_bounds);
			}
		}
		if (chunk_size.x == 64)
		{
			//load the bottom level of foliage			
			for (auto& bottomPlant : terrain->bottomFoliageLayer)
			{
				bottomPlant->bHasSpawnned = false;
				bottomPlant->GenerateFoliagePositions(node->chunk_bounds);
			}
		}
	}

	//Quad tree for terrain
	void QuadTree::CreateChildren(QNode*& node, Camera& cam)
	{
		glm::vec3 mid_point = node->chunk_bounds.GetMidPoint();
		glm::vec3 bounds_min = node->chunk_bounds.aabbMin;
		glm::vec3 bounds_max = node->chunk_bounds.aabbMax;
		
		//if there is no children then crate them
		if (node->childrens.size() == 0)
		{
			//bottom left
			QNode* bl = NodePool::GetNode(Bounds(glm::vec3(mid_point.x, 0, bounds_min.z), glm::vec3(bounds_max.x, 0, mid_point.z)));
			//bottom right
			QNode* br = NodePool::GetNode(Bounds(bounds_min, mid_point));
			//top left
			QNode* tl = NodePool::GetNode(Bounds(mid_point, bounds_max));
			//top right
			QNode* tr = NodePool::GetNode(Bounds(glm::vec3(bounds_min.x, 0, mid_point.z), glm::vec3(mid_point.x, 0, bounds_max.z)));

			if (bl && br && tl && tr) 
			{
				SpawnFoliageAtTile(bl, cam);
				SpawnFoliageAtTile(br, cam);
				SpawnFoliageAtTile(tl, cam);
				SpawnFoliageAtTile(tr, cam);

				node->childrens.push_back(bl);
				node->childrens.push_back(br);
				node->childrens.push_back(tl);
				node->childrens.push_back(tr);
			}
		}
	}
	void QuadTree::Insert(QNode*& node, Camera& cam)
	{
		glm::vec3 extent = node->chunk_bounds.aabbMax - node->chunk_bounds.aabbMin;
		glm::vec3 mid_point = node->chunk_bounds.GetMidPoint();
		glm::vec3 cam_pos = cam.GetCameraPosition();
		float boxSize = 512.f;
		Bounds player_bounds(cam_pos - glm::vec3(boxSize, 0.0f, boxSize), cam_pos + glm::vec3(boxSize, 0.0f, boxSize));

		//check if the size of the chunk is greater than the min size (64.0)
		if(extent.x >= 64.0f && extent.z >= 64.0f && aabbIntersection(player_bounds, node->chunk_bounds))
		{
			CreateChildren(node, cam);
		}

		for (QNode* x : node->childrens)
		{
			Insert(x, cam);
		}
	}

	void QuadTree::GetChildren(QNode*& node, std::vector<QNode*>& childrens)
	{
		if (node->childrens.size() == 0)
			childrens.push_back(node);
		for (QNode* x : node->childrens)
		{
			GetChildren(x, childrens);
		}
	}
	void QuadTree::DeleteNodesIfNotInScope(QNode* node, Camera& cam)
	{
		glm::vec3 extent = node->chunk_bounds.aabbMax - node->chunk_bounds.aabbMin;
		glm::vec3 mid_point = node->chunk_bounds.GetMidPoint();
		glm::vec3 cam_pos = cam.GetCameraPosition();
		float boxSize = 512.0f;
		Bounds player_bounds(cam_pos - glm::vec3(boxSize, 0.0f, boxSize), cam_pos + glm::vec3(boxSize, 0.0f, boxSize));

		if (!aabbIntersection(player_bounds,node->chunk_bounds))
		{
			DeleteNode(node);
			node->childrens.clear();
		}

		for (QNode* x : node->childrens)
		{
			DeleteNodesIfNotInScope(x, cam);
		}
	}
	void QuadTree::DeleteNode(QNode*& node)
	{
		const glm::vec3& extent = node->chunk_bounds.aabbMax - node->chunk_bounds.aabbMin;
		glm::vec3& player_pos = terrain->player_camera_pos;

		for (QNode*& child : node->childrens)
		{
			glm::vec3& bounds_min = child->chunk_bounds.aabbMin;
			glm::vec3& bounds_max = child->chunk_bounds.aabbMax;
			const glm::vec3& chunk_size = bounds_max - bounds_min;
			if (chunk_size.x == 256)
			{
				for (auto& topPlant : terrain->topFoliageLayer)
					topPlant->RemoveFoliagePositions(child->chunk_bounds);
			}
			if (chunk_size.x == 128)
			{
				for (auto& middlePlant : terrain->middleFoliageLayer)
					middlePlant->RemoveFoliagePositions(child->chunk_bounds);
			}
			if (chunk_size.x == 64)
			{
				for (auto& bottoPlant : terrain->bottomFoliageLayer)
					bottoPlant->RemoveFoliagePositions(child->chunk_bounds);
			}
			DeleteNode(child);
			NodePool::RecycleMemory(child); //delete the node by resetting the reference and recycling the allocated memory
		}

	}

	bool QuadTree::aabbIntersection(Bounds& box1, Bounds& box2)
	{
		bool doesIntersect = box1.aabbMin.x <= box2.aabbMax.x &&
							 box1.aabbMax.x >= box2.aabbMin.x &&
							 box1.aabbMin.z <= box2.aabbMax.z &&
							 box1.aabbMax.z >= box2.aabbMin.z;
		return doesIntersect;
	}
	
	QNode::~QNode()
	{
	}


	// set higher than allocTime min time so we can start allocating immeditaly
	float NodePool::allocTime = 1.1f;

	QNode* NodePool::GetNode(Bounds bounds)
	{
		if (!node_memoryPool.empty())
		{
			node_memoryPool.top()->childrens.clear();
			node_memoryPool.top()->chunk_bounds = bounds;
			QNode* node = node_memoryPool.top();
			node_memoryPool.pop();
			return node;
		}
		else
		{
			//if stack is empty allocate new chunks of memory, we also need to be able to allocate
			if (!Allocate())
				return nullptr;
			node_memoryPool.top()->childrens.clear();
			node_memoryPool.top()->chunk_bounds = bounds;
			QNode* node = node_memoryPool.top();
			node_memoryPool.pop();
			return node;
		}
	}
	void NodePool::RecycleMemory(QNode*& node)
	{
		// allocTime is temp, just messing around with allocation timing to reduce screen tearing when we allocate nodes
		// even though its allocTime we also need to think about dealloc time, trying to constantly call delete with .clear
		// since our vector is filled with dynamicly allocated memory it will be slow

		if (allocTime > 1.f) 
		{
			node->childrens.clear();
			NodePool::node_memoryPool.push(node); //when we want to deallocate a node just recycle the memory to memory pool
			node = nullptr; //delete the node
			CN_CORE_TRACE("Quad Tree Node Deleted and memory recycled");
			allocTime = 0.0f;
		}

		allocTime += 0.001f;
	}
	bool NodePool::Allocate()
	{

		// allocTime is temp, just messing around with allocation timing to reduce screen tearing when we allocate nodes
		if (allocTime > 0.5f) {

			//CN_CORE_TRACE("Allocating Memory, Initial Pool Size -> {}", NodePool::node_memoryPool.size());

			for (int i = 0; i < 5; i++) //allocate 20 new nodes
			{
				NodePool::node_memoryPool.push(new QNode());
			}
			//CN_CORE_TRACE("Allocated Memory!, Pool Size -> {}", NodePool::node_memoryPool.size());

			allocTime = 0.0f;

			return true;
		}

		allocTime += 0.001;

		return false;

	}
	void NodePool::DeAllocate()
	{
		while (!NodePool::node_memoryPool.empty())
		{
			delete NodePool::node_memoryPool.top();
			NodePool::node_memoryPool.pop();
		}
	}
}