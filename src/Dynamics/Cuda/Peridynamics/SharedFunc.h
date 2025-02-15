/**
 * Copyright 2021 Xiaowei He
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      https://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
#pragma once
#include "Array/Array.h"
#include "Array/ArrayList.h"

#include "NeighborData.h"
#include "DataTypes.h"

namespace dyno {
	template<typename Coord, typename NPair>
	void constructRestShape(
		DArrayList<NPair>& shape,
		DArrayList<int>& nbr,
		DArray<Coord>& pos);
}
