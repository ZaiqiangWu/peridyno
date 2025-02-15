#include "QuadSet.h"
#include <fstream>
#include <iostream>
#include <sstream>

#include <thrust/sort.h>

namespace dyno
{

	template<typename TDataType>
	QuadSet<TDataType>::QuadSet()
		: TriangleSet<TDataType>()
	{
	}

	template<typename TDataType>
	QuadSet<TDataType>::~QuadSet()
	{
	}

	template<typename Quad>
	__global__ void QS_CountQuads(
		DArray<uint> counter,
		DArray<Quad> quads)
	{
		int tId = threadIdx.x + (blockIdx.x * blockDim.x);
		if (tId >= quads.size()) return;

		Quad q = quads[tId];

		atomicAdd(&counter[q[0]], 1);
		atomicAdd(&counter[q[1]], 1);
		atomicAdd(&counter[q[2]], 1);
		atomicAdd(&counter[q[3]], 1);
	}

	template<typename Quad>
	__global__ void QS_SetupQuadIds(
		DArrayList<int> quadIds,
		DArray<Quad> quads)
	{
		int tId = threadIdx.x + (blockIdx.x * blockDim.x);
		if (tId >= quads.size()) return;

		Quad q = quads[tId];

		quadIds[q[0]].atomicInsert(tId);
		quadIds[q[1]].atomicInsert(tId);
		quadIds[q[2]].atomicInsert(tId);
		quadIds[q[3]].atomicInsert(tId);
	}

	template<typename TDataType>
	DArrayList<int>& QuadSet<TDataType>::getVertex2Quads()
	{
		DArray<uint> counter(this->m_coords.size());
		counter.reset();

		cuExecute(m_quads.size(),
			QS_CountQuads,
			counter,
			m_quads);

		m_ver2Quad.resize(counter);

		counter.reset();
		cuExecute(m_quads.size(),
			QS_SetupQuadIds,
			m_ver2Quad,
			m_quads);

		counter.clear();

		return m_ver2Quad;
	}

	template<typename EKey, typename Quad>
	__global__ void QS_SetupKeys(
		DArray<EKey> keys,
		DArray<int> ids,
		DArray<Quad> quads)
	{
		int tId = threadIdx.x + (blockIdx.x * blockDim.x);
		if (tId >= quads.size()) return;

		Quad quad = quads[tId];
		keys[4 * tId] = EKey(quad[0], quad[1]);
		keys[4 * tId + 1] = EKey(quad[1], quad[2]);
		keys[4 * tId + 2] = EKey(quad[2], quad[3]);
		keys[4 * tId + 3] = EKey(quad[3], quad[0]);

		ids[4 * tId] = tId;
		ids[4 * tId + 1] = tId;
		ids[4 * tId + 2] = tId;
		ids[4 * tId + 3] = tId;
	}

	template<typename EKey>
	__global__ void QS_CountEdgeNumber(
		DArray<int> counter,
		DArray<EKey> keys)
	{
		int tId = threadIdx.x + (blockIdx.x * blockDim.x);
		if (tId >= keys.size()) return;

		if (tId == 0 || keys[tId] != keys[tId - 1])
			counter[tId] = 1;
		else
			counter[tId] = 0;
	}

	template<typename Edge, typename Edg2Quad, typename EKey>
	__global__ void QS_SetupEdges(
		DArray<Edge> edges,
		DArray<Edg2Quad> edg2Quad,
		DArray<EKey> keys,
		DArray<int> counter,
		DArray<int> quadIds)
	{
		int tId = threadIdx.x + (blockIdx.x * blockDim.x);
		if (tId >= keys.size()) return;

		int shift = counter[tId];
		if (tId == 0 || keys[tId] != keys[tId - 1])
		{
			EKey key = keys[tId];
			edges[shift] = Edge(key[0], key[1]);

			Edg2Quad e2Q(EMPTY, EMPTY);
			e2Q[0] = quadIds[tId];

			if (tId + 1 < keys.size() && keys[tId + 1] == key)
				e2Q[1] = quadIds[tId + 1];

			edg2Quad[shift] = e2Q;

			 			//printf("T2T %d: %d %d \n", shift, t2T[0], t2T[1]);
			 
			 			//printf("Tri %d: %d %d %d; Tet: %d \n", shift, keys[tId][0], keys[tId][1], keys[tId][2], tetIds[tId]);
			 			//printf("Counter: %d \n", shift, counter[tId]);
		}
	}

	template<typename TDataType>
	void QuadSet<TDataType>::updateEdges()
	{
		uint quadSize = m_quads.size();
		DArray<EKey> keys;
		DArray<int> quadIds;

		keys.resize(4 * quadSize);
		quadIds.resize(4 * quadSize);

		cuExecute(quadSize,
			QS_SetupKeys,
			keys,
			quadIds,
			m_quads);

		thrust::sort_by_key(thrust::device, keys.begin(), keys.begin() + keys.size(), quadIds.begin());

		DArray<int> counter;
		counter.resize(4 * quadSize);

		cuExecute(keys.size(),
			QS_CountEdgeNumber,
			counter,
			keys);

		int edgeNum = thrust::reduce(thrust::device, counter.begin(), counter.begin() + counter.size());
		thrust::exclusive_scan(thrust::device, counter.begin(), counter.begin() + counter.size(), counter.begin());

		edg2Quad.resize(edgeNum);

		auto& pEdges = this->getEdges();
		pEdges.resize(edgeNum);
		cuExecute(keys.size(),
			QS_SetupEdges,
			pEdges,
			edg2Quad,
			keys,
			counter,
			quadIds);

		counter.clear();
		quadIds.clear();
		keys.clear();
	}

	template<typename TDataType>
	void QuadSet<TDataType>::setQuads(std::vector<Quad>& quads)
	{
		m_quads.resize(quads.size());
		m_quads.assign(quads);

		//this->updateTriangles();
	}


	template<typename TDataType>
	void QuadSet<TDataType>::copyFrom(QuadSet<TDataType>& quadSet)
	{
		m_ver2Quad.assign(quadSet.m_ver2Quad);

		m_quads.resize(quadSet.m_quads.size());
		m_quads.assign(quadSet.m_quads);

		edg2Quad.resize(quadSet.edg2Quad.size());
		edg2Quad.assign(quadSet.edg2Quad);

		EdgeSet<TDataType>::copyFrom(quadSet);
	}

	template<typename Coord, typename Quad>
	__global__ void QS_SetupVertexNormals(
		DArray<Coord> normals,
		DArray<Coord> vertices,
		DArray<Quad> quads,
		DArrayList<int> quadIds)
	{
		int tId = threadIdx.x + (blockIdx.x * blockDim.x);
		if (tId >= normals.size()) return;

		List<int>& list_i = quadIds[tId];
		int quadSize = list_i.size();

		Coord N = Coord(0);
		for (int ne = 0; ne < quadSize; ne++)
		{
			int j = list_i[ne];
			Quad t = quads[j];

			Coord v0 = vertices[t[0]];
			Coord v1 = vertices[t[1]];
			Coord v2 = vertices[t[2]];
			Coord v3 = vertices[t[3]];

			N += (v1 - v0).cross(v2 - v0);
		}

		N.normalize();

		normals[tId] = N;
	}

	template<typename TDataType>
	void QuadSet<TDataType>::updateTopology()
	{
		this->updateQuads();

		TriangleSet<TDataType>::updateTopology();
	}

	template<typename TDataType>
	void QuadSet<TDataType>::updateVertexNormal()
	{
		if (this->outVertexNormal()->isEmpty())
			this->outVertexNormal()->allocate();

		auto& vn = this->outVertexNormal()->getData();

		uint vertSize = this->m_coords.size();

		if (vn.size() != vertSize) {
			vn.resize(vertSize);
		}

		auto& vert2Quad = getVertex2Quads();

		cuExecute(vertSize,
			QS_SetupVertexNormals,
			vn,
			this->m_coords,
			m_quads,
			vert2Quad);
	}

	template<typename Triangle, typename Quad>
	__global__ void TS_SetupTriangles(
		DArray<Triangle> triangles,
		DArray<Quad> quads)
	{
		int tId = threadIdx.x + (blockIdx.x * blockDim.x);
		if (tId >= quads.size()) return;

		Quad quad = quads[tId];
		triangles[2 * tId] = Triangle(quad[0], quad[1], quad[2]);
		triangles[2 * tId + 1] = Triangle(quad[0], quad[2], quad[3]);
	}

	template<typename TDataType>
	void QuadSet<TDataType>::updateTriangles()
	{
		uint quadSize = m_quads.size();

		auto& pTri = this->getTriangles();
		pTri.resize(2 * quadSize);

		cuExecute(quadSize,
			TS_SetupTriangles,
			pTri,
			m_quads);
	}

	DEFINE_CLASS(QuadSet);
}