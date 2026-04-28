// Copyright 2020-2021 Paweł Jastrzębski
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//    http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

// Precompiled header file
#include "stdafx.h"
#include <random>
#include <fstream>

using namespace RResources;
using namespace CComponents;
using namespace CResources;

namespace Intrinsic
{
namespace Renderer
{
namespace RenderPass
{
namespace
{
  // clang-format off
  // Lookup table: which edges of a cube are intersected by the isosurface,
  // indexed by the 8-bit vertex sign pattern (256 entries).
  static int cubeEdgeFlags[256] = {
    0x000, 0x109, 0x203, 0x30a, 0x406, 0x50f, 0x605, 0x70c,
    0x80c, 0x905, 0xa0f, 0xb06, 0xc0a, 0xd03, 0xe09, 0xf00,
    0x190, 0x099, 0x393, 0x29a, 0x596, 0x49f, 0x795, 0x69c,
    0x99c, 0x895, 0xb9f, 0xa96, 0xd9a, 0xc93, 0xf99, 0xe90,
    0x230, 0x339, 0x033, 0x13a, 0x636, 0x73f, 0x435, 0x53c,
    0xa3c, 0xb35, 0x83f, 0x936, 0xe3a, 0xf33, 0xc39, 0xd30,
    0x3a0, 0x2a9, 0x1a3, 0x0aa, 0x7a6, 0x6af, 0x5a5, 0x4ac,
    0xbac, 0xaa5, 0x9af, 0x8a6, 0xfaa, 0xea3, 0xda9, 0xca0,
    0x460, 0x569, 0x663, 0x76a, 0x066, 0x16f, 0x265, 0x36c,
    0xc6c, 0xd65, 0xe6f, 0xf66, 0x86a, 0x963, 0xa69, 0xb60,
    0x5f0, 0x4f9, 0x7f3, 0x6fa, 0x1f6, 0x0ff, 0x3f5, 0x2fc,
    0xdfc, 0xcf5, 0xfff, 0xef6, 0x9fa, 0x8f3, 0xbf9, 0xaf0,
    0x650, 0x759, 0x453, 0x55a, 0x256, 0x35f, 0x055, 0x15c,
    0xe5c, 0xf55, 0xc5f, 0xd56, 0xa5a, 0xb53, 0x859, 0x950,
    0x7c0, 0x6c9, 0x5c3, 0x4ca, 0x3c6, 0x2cf, 0x1c5, 0x0cc,
    0xfcc, 0xec5, 0xdcf, 0xcc6, 0xbca, 0xac3, 0x9c9, 0x8c0,
    0x8c0, 0x9c9, 0xac3, 0xbca, 0xcc6, 0xdcf, 0xec5, 0xfcc,
    0x0cc, 0x1c5, 0x2cf, 0x3c6, 0x4ca, 0x5c3, 0x6c9, 0x7c0,
    0x950, 0x859, 0xb53, 0xa5a, 0xd56, 0xc5f, 0xf55, 0xe5c,
    0x15c, 0x055, 0x35f, 0x256, 0x55a, 0x453, 0x759, 0x650,
    0xaf0, 0xbf9, 0x8f3, 0x9fa, 0xef6, 0xfff, 0xcf5, 0xdfc,
    0x2fc, 0x3f5, 0x0ff, 0x1f6, 0x6fa, 0x7f3, 0x4f9, 0x5f0,
    0xb60, 0xa69, 0x963, 0x86a, 0xf66, 0xe6f, 0xd65, 0xc6c,
    0x36c, 0x265, 0x16f, 0x066, 0x76a, 0x663, 0x569, 0x460,
    0xca0, 0xda9, 0xea3, 0xfaa, 0x8a6, 0x9af, 0xaa5, 0xbac,
    0x4ac, 0x5a5, 0x6af, 0x7a6, 0x0aa, 0x1a3, 0x2a9, 0x3a0,
    0xd30, 0xc39, 0xf33, 0xe3a, 0x936, 0x83f, 0xb35, 0xa3c,
    0x53c, 0x435, 0x73f, 0x636, 0x13a, 0x033, 0x339, 0x230,
    0xe90, 0xf99, 0xc93, 0xd9a, 0xa96, 0xb9f, 0x895, 0x99c,
    0x69c, 0x795, 0x49f, 0x596, 0x29a, 0x393, 0x099, 0x190,
    0xf00, 0xe09, 0xd03, 0xc0a, 0xb06, 0xa0f, 0x905, 0x80c,
    0x70c, 0x605, 0x50f, 0x406, 0x30a, 0x203, 0x109, 0x000
  };

  // Lookup table: triangle vertex indices per cube configuration.
  // 16 ints per entry (4096 total); -1 terminates the triangle list.
  static int triangleConnectionTable[4096] = {
    -1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
    0,8,3,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
    0,1,9,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
    1,8,3,9,8,1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
    1,2,10,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
    0,8,3,1,2,10,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
    9,2,10,0,2,9,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
    2,8,3,2,10,8,10,9,8,-1,-1,-1,-1,-1,-1,-1,
    3,11,2,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
    0,11,2,8,11,0,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
    1,9,0,2,3,11,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
    1,11,2,1,9,11,9,8,11,-1,-1,-1,-1,-1,-1,-1,
    3,10,1,11,10,3,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
    0,10,1,0,8,10,8,11,10,-1,-1,-1,-1,-1,-1,-1,
    3,9,0,3,11,9,11,10,9,-1,-1,-1,-1,-1,-1,-1,
    9,8,10,10,8,11,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
    4,7,8,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
    4,3,0,7,3,4,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
    0,1,9,8,4,7,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
    4,1,9,4,7,1,7,3,1,-1,-1,-1,-1,-1,-1,-1,
    1,2,10,8,4,7,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
    3,4,7,3,0,4,1,2,10,-1,-1,-1,-1,-1,-1,-1,
    9,2,10,9,0,2,8,4,7,-1,-1,-1,-1,-1,-1,-1,
    2,10,9,2,9,7,2,7,3,7,9,4,-1,-1,-1,-1,
    8,4,7,3,11,2,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
    11,4,7,11,2,4,2,0,4,-1,-1,-1,-1,-1,-1,-1,
    9,0,1,8,4,7,2,3,11,-1,-1,-1,-1,-1,-1,-1,
    4,7,11,9,4,11,9,11,2,9,2,1,-1,-1,-1,-1,
    3,10,1,3,11,10,7,8,4,-1,-1,-1,-1,-1,-1,-1,
    1,11,10,1,4,11,1,0,4,7,11,4,-1,-1,-1,-1,
    4,7,8,9,0,11,9,11,10,11,0,3,-1,-1,-1,-1,
    4,7,11,4,11,9,9,11,10,-1,-1,-1,-1,-1,-1,-1,
    9,5,4,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
    9,5,4,0,8,3,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
    0,5,4,1,5,0,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
    8,5,4,8,3,5,3,1,5,-1,-1,-1,-1,-1,-1,-1,
    1,2,10,9,5,4,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
    3,0,8,1,2,10,4,9,5,-1,-1,-1,-1,-1,-1,-1,
    5,2,10,5,4,2,4,0,2,-1,-1,-1,-1,-1,-1,-1,
    2,10,5,3,2,5,3,5,4,3,4,8,-1,-1,-1,-1,
    9,5,4,2,3,11,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
    0,11,2,0,8,11,4,9,5,-1,-1,-1,-1,-1,-1,-1,
    0,5,4,0,1,5,2,3,11,-1,-1,-1,-1,-1,-1,-1,
    2,1,5,2,5,8,2,8,11,4,8,5,-1,-1,-1,-1,
    10,3,11,10,1,3,9,5,4,-1,-1,-1,-1,-1,-1,-1,
    4,9,5,0,8,1,8,10,1,8,11,10,-1,-1,-1,-1,
    5,4,0,5,0,11,5,11,10,11,0,3,-1,-1,-1,-1,
    5,4,8,5,8,10,10,8,11,-1,-1,-1,-1,-1,-1,-1,
    9,7,8,5,7,9,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
    9,3,0,9,5,3,5,7,3,-1,-1,-1,-1,-1,-1,-1,
    0,7,8,0,1,7,1,5,7,-1,-1,-1,-1,-1,-1,-1,
    1,5,3,3,5,7,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
    9,7,8,9,5,7,10,1,2,-1,-1,-1,-1,-1,-1,-1,
    10,1,2,9,5,0,5,3,0,5,7,3,-1,-1,-1,-1,
    8,0,2,8,2,5,8,5,7,10,5,2,-1,-1,-1,-1,
    2,10,5,2,5,3,3,5,7,-1,-1,-1,-1,-1,-1,-1,
    7,9,5,7,8,9,3,11,2,-1,-1,-1,-1,-1,-1,-1,
    9,5,7,9,7,2,9,2,0,2,7,11,-1,-1,-1,-1,
    2,3,11,0,1,8,1,7,8,1,5,7,-1,-1,-1,-1,
    11,2,1,11,1,7,7,1,5,-1,-1,-1,-1,-1,-1,-1,
    9,5,8,8,5,7,10,1,3,10,3,11,-1,-1,-1,-1,
    5,7,0,5,0,9,7,11,0,1,0,10,11,10,0,-1,
    11,10,0,11,0,3,10,5,0,8,0,7,5,7,0,-1,
    11,10,5,7,11,5,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
    10,6,5,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
    0,8,3,5,10,6,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
    9,0,1,5,10,6,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
    1,8,3,1,9,8,5,10,6,-1,-1,-1,-1,-1,-1,-1,
    1,6,5,2,6,1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
    1,6,5,1,2,6,3,0,8,-1,-1,-1,-1,-1,-1,-1,
    9,6,5,9,0,6,0,2,6,-1,-1,-1,-1,-1,-1,-1,
    5,9,8,5,8,2,5,2,6,3,2,8,-1,-1,-1,-1,
    2,3,11,10,6,5,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
    11,0,8,11,2,0,10,6,5,-1,-1,-1,-1,-1,-1,-1,
    0,1,9,2,3,11,5,10,6,-1,-1,-1,-1,-1,-1,-1,
    5,10,6,1,9,2,9,11,2,9,8,11,-1,-1,-1,-1,
    6,3,11,6,5,3,5,1,3,-1,-1,-1,-1,-1,-1,-1,
    0,8,11,0,11,5,0,5,1,5,11,6,-1,-1,-1,-1,
    3,11,6,0,3,6,0,6,5,0,5,9,-1,-1,-1,-1,
    6,5,9,6,9,11,11,9,8,-1,-1,-1,-1,-1,-1,-1,
    5,10,6,4,7,8,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
    4,3,0,4,7,3,6,5,10,-1,-1,-1,-1,-1,-1,-1,
    1,9,0,5,10,6,8,4,7,-1,-1,-1,-1,-1,-1,-1,
    10,6,5,1,9,7,1,7,3,7,9,4,-1,-1,-1,-1,
    6,1,2,6,5,1,4,7,8,-1,-1,-1,-1,-1,-1,-1,
    1,2,5,5,2,6,3,0,4,3,4,7,-1,-1,-1,-1,
    8,4,7,9,0,5,0,6,5,0,2,6,-1,-1,-1,-1,
    7,3,9,7,9,4,3,2,9,5,9,6,2,6,9,-1,
    3,11,2,7,8,4,10,6,5,-1,-1,-1,-1,-1,-1,-1,
    5,10,6,4,7,2,4,2,0,2,7,11,-1,-1,-1,-1,
    0,1,9,4,7,8,2,3,11,5,10,6,-1,-1,-1,-1,
    9,2,1,9,11,2,9,4,11,7,11,4,5,10,6,-1,
    8,4,7,3,11,5,3,5,1,5,11,6,-1,-1,-1,-1,
    5,1,11,5,11,6,1,0,11,7,11,4,0,4,11,-1,
    0,5,9,0,6,5,0,3,6,11,6,3,8,4,7,-1,
    6,5,9,6,9,11,4,7,9,7,11,9,-1,-1,-1,-1,
    10,4,9,6,4,10,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
    4,10,6,4,9,10,0,8,3,-1,-1,-1,-1,-1,-1,-1,
    10,0,1,10,6,0,6,4,0,-1,-1,-1,-1,-1,-1,-1,
    8,3,1,8,1,6,8,6,4,6,1,10,-1,-1,-1,-1,
    1,4,9,1,2,4,2,6,4,-1,-1,-1,-1,-1,-1,-1,
    3,0,8,1,2,9,2,4,9,2,6,4,-1,-1,-1,-1,
    0,2,4,4,2,6,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
    8,3,2,8,2,4,4,2,6,-1,-1,-1,-1,-1,-1,-1,
    10,4,9,10,6,4,11,2,3,-1,-1,-1,-1,-1,-1,-1,
    0,8,2,2,8,11,4,9,10,4,10,6,-1,-1,-1,-1,
    3,11,2,0,1,6,0,6,4,6,1,10,-1,-1,-1,-1,
    6,4,1,6,1,10,4,8,1,2,1,11,8,11,1,-1,
    9,6,4,9,3,6,9,1,3,11,6,3,-1,-1,-1,-1,
    8,11,1,8,1,0,11,6,1,9,1,4,6,4,1,-1,
    3,11,6,3,6,0,0,6,4,-1,-1,-1,-1,-1,-1,-1,
    6,4,8,11,6,8,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
    7,10,6,7,8,10,8,9,10,-1,-1,-1,-1,-1,-1,-1,
    0,7,3,0,10,7,0,9,10,6,7,10,-1,-1,-1,-1,
    10,6,7,1,10,7,1,7,8,1,8,0,-1,-1,-1,-1,
    10,6,7,10,7,1,1,7,3,-1,-1,-1,-1,-1,-1,-1,
    1,2,6,1,6,8,1,8,9,8,6,7,-1,-1,-1,-1,
    2,6,9,2,9,1,6,7,9,0,9,3,7,3,9,-1,
    7,8,0,7,0,6,6,0,2,-1,-1,-1,-1,-1,-1,-1,
    7,3,2,6,7,2,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
    2,3,11,10,6,8,10,8,9,8,6,7,-1,-1,-1,-1,
    2,0,7,2,7,11,0,9,7,6,7,10,9,10,7,-1,
    1,8,0,1,7,8,1,10,7,6,7,10,2,3,11,-1,
    11,2,1,11,1,7,10,6,1,6,7,1,-1,-1,-1,-1,
    8,9,6,8,6,7,9,1,6,11,6,3,1,3,6,-1,
    0,9,1,11,6,7,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
    7,8,0,7,0,6,3,11,0,11,6,0,-1,-1,-1,-1,
    7,11,6,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
    7,6,11,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
    3,0,8,11,7,6,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
    0,1,9,11,7,6,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
    8,1,9,8,3,1,11,7,6,-1,-1,-1,-1,-1,-1,-1,
    10,1,2,6,11,7,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
    1,2,10,3,0,8,6,11,7,-1,-1,-1,-1,-1,-1,-1,
    2,9,0,2,10,9,6,11,7,-1,-1,-1,-1,-1,-1,-1,
    6,11,7,2,10,3,10,8,3,10,9,8,-1,-1,-1,-1,
    7,2,3,6,2,7,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
    7,0,8,7,6,0,6,2,0,-1,-1,-1,-1,-1,-1,-1,
    2,7,6,2,3,7,0,1,9,-1,-1,-1,-1,-1,-1,-1,
    1,6,2,1,8,6,1,9,8,8,7,6,-1,-1,-1,-1,
    10,7,6,10,1,7,1,3,7,-1,-1,-1,-1,-1,-1,-1,
    10,7,6,1,7,10,1,8,7,1,0,8,-1,-1,-1,-1,
    0,3,7,0,7,10,0,10,9,6,10,7,-1,-1,-1,-1,
    7,6,10,7,10,8,8,10,9,-1,-1,-1,-1,-1,-1,-1,
    6,8,4,11,8,6,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
    3,6,11,3,0,6,0,4,6,-1,-1,-1,-1,-1,-1,-1,
    8,6,11,8,4,6,9,0,1,-1,-1,-1,-1,-1,-1,-1,
    9,4,6,9,6,3,9,3,1,11,3,6,-1,-1,-1,-1,
    6,8,4,6,11,8,2,10,1,-1,-1,-1,-1,-1,-1,-1,
    1,2,10,3,0,11,0,6,11,0,4,6,-1,-1,-1,-1,
    4,11,8,4,6,11,0,2,9,2,10,9,-1,-1,-1,-1,
    10,9,3,10,3,2,9,4,3,11,3,6,4,6,3,-1,
    8,2,3,8,4,2,4,6,2,-1,-1,-1,-1,-1,-1,-1,
    0,4,2,4,6,2,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
    1,9,0,2,3,4,2,4,6,4,3,8,-1,-1,-1,-1,
    1,9,4,1,4,2,2,4,6,-1,-1,-1,-1,-1,-1,-1,
    8,1,3,8,6,1,8,4,6,6,10,1,-1,-1,-1,-1,
    10,1,0,10,0,6,6,0,4,-1,-1,-1,-1,-1,-1,-1,
    4,6,3,4,3,8,6,10,3,0,3,9,10,9,3,-1,
    10,9,4,6,10,4,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
    4,9,5,7,6,11,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
    0,8,3,4,9,5,11,7,6,-1,-1,-1,-1,-1,-1,-1,
    5,0,1,5,4,0,7,6,11,-1,-1,-1,-1,-1,-1,-1,
    11,7,6,8,3,4,3,5,4,3,1,5,-1,-1,-1,-1,
    9,5,4,10,1,2,7,6,11,-1,-1,-1,-1,-1,-1,-1,
    6,11,7,1,2,10,0,8,3,4,9,5,-1,-1,-1,-1,
    7,6,11,5,4,10,4,2,10,4,0,2,-1,-1,-1,-1,
    3,4,8,3,5,4,3,2,5,10,5,2,11,7,6,-1,
    7,2,3,7,6,2,5,4,9,-1,-1,-1,-1,-1,-1,-1,
    9,5,4,0,8,6,0,6,2,6,8,7,-1,-1,-1,-1,
    3,6,2,3,7,6,1,5,0,5,4,0,-1,-1,-1,-1,
    6,2,8,6,8,7,2,1,8,4,8,5,1,5,8,-1,
    9,5,4,10,1,6,1,7,6,1,3,7,-1,-1,-1,-1,
    1,6,10,1,7,6,1,0,7,8,7,0,9,5,4,-1,
    4,0,10,4,10,5,0,3,10,6,10,7,3,7,10,-1,
    7,6,10,7,10,8,5,4,10,4,8,10,-1,-1,-1,-1,
    6,9,5,6,11,9,11,8,9,-1,-1,-1,-1,-1,-1,-1,
    3,6,11,0,6,3,0,5,6,0,9,5,-1,-1,-1,-1,
    0,11,8,0,5,11,0,1,5,5,6,11,-1,-1,-1,-1,
    6,11,3,6,3,5,5,3,1,-1,-1,-1,-1,-1,-1,-1,
    1,2,10,9,5,11,9,11,8,11,5,6,-1,-1,-1,-1,
    0,11,3,0,6,11,0,9,6,5,6,9,1,2,10,-1,
    11,8,5,11,5,6,8,0,5,10,5,2,0,2,5,-1,
    6,11,3,6,3,5,2,10,3,10,5,3,-1,-1,-1,-1,
    5,8,9,5,2,8,5,6,2,3,8,2,-1,-1,-1,-1,
    9,5,6,9,6,0,0,6,2,-1,-1,-1,-1,-1,-1,-1,
    1,5,8,1,8,0,5,6,8,3,8,2,6,2,8,-1,
    1,5,6,2,1,6,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
    1,3,6,1,6,10,3,8,6,5,6,9,8,9,6,-1,
    10,1,0,10,0,6,9,5,0,5,6,0,-1,-1,-1,-1,
    0,3,8,5,6,10,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
    10,5,6,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
    11,5,10,7,5,11,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
    11,5,10,11,7,5,8,3,0,-1,-1,-1,-1,-1,-1,-1,
    5,11,7,5,10,11,1,9,0,-1,-1,-1,-1,-1,-1,-1,
    10,7,5,10,11,7,9,8,1,8,3,1,-1,-1,-1,-1,
    11,1,2,11,7,1,7,5,1,-1,-1,-1,-1,-1,-1,-1,
    0,8,3,1,2,7,1,7,5,7,2,11,-1,-1,-1,-1,
    9,7,5,9,2,7,9,0,2,2,11,7,-1,-1,-1,-1,
    7,5,2,7,2,11,5,9,2,3,2,8,9,8,2,-1,
    2,5,10,2,3,5,3,7,5,-1,-1,-1,-1,-1,-1,-1,
    8,2,0,8,5,2,8,7,5,10,2,5,-1,-1,-1,-1,
    9,0,1,2,3,10,3,5,10,3,7,5,-1,-1,-1,-1,
    1,2,5,5,2,10,9,8,5,8,7,5,8,3,7,-1,
    5,1,3,5,3,7,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
    0,8,7,0,7,1,1,7,5,-1,-1,-1,-1,-1,-1,-1,
    9,0,3,9,3,5,5,3,7,-1,-1,-1,-1,-1,-1,-1,
    9,8,7,5,9,7,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
    5,8,4,5,10,8,10,11,8,-1,-1,-1,-1,-1,-1,-1,
    5,0,4,5,11,0,5,10,11,11,3,0,-1,-1,-1,-1,
    0,1,9,8,4,10,8,10,11,10,4,5,-1,-1,-1,-1,
    10,11,4,10,4,5,11,3,4,9,4,1,3,1,4,-1,
    2,5,1,2,8,5,2,11,8,4,5,8,-1,-1,-1,-1,
    0,4,11,0,11,3,4,5,11,2,11,1,5,1,11,-1,
    0,2,5,0,5,9,2,11,5,4,5,8,11,8,5,-1,
    9,4,5,2,11,3,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
    2,5,10,3,5,2,3,4,5,3,8,4,-1,-1,-1,-1,
    5,10,2,5,2,4,4,2,0,-1,-1,-1,-1,-1,-1,-1,
    3,10,2,3,5,10,3,8,5,4,5,8,0,1,9,-1,
    5,10,2,5,2,4,1,9,2,9,4,2,-1,-1,-1,-1,
    8,4,5,8,5,3,3,5,1,-1,-1,-1,-1,-1,-1,-1,
    0,4,5,1,0,5,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
    8,4,5,8,5,3,9,0,5,0,3,5,-1,-1,-1,-1,
    9,4,5,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
    4,11,7,4,9,11,9,10,11,-1,-1,-1,-1,-1,-1,-1,
    0,8,3,4,9,7,9,11,7,9,10,11,-1,-1,-1,-1,
    1,10,11,1,11,4,1,4,0,7,4,11,-1,-1,-1,-1,
    3,1,4,3,4,8,1,10,4,7,4,11,10,11,4,-1,
    4,11,7,9,11,4,9,2,11,9,1,2,-1,-1,-1,-1,
    9,7,4,9,11,7,9,1,11,2,11,1,0,8,3,-1,
    11,7,4,11,4,2,2,4,0,-1,-1,-1,-1,-1,-1,-1,
    11,7,4,11,4,2,8,3,4,3,2,4,-1,-1,-1,-1,
    2,9,10,2,7,9,2,3,7,7,4,9,-1,-1,-1,-1,
    9,10,7,9,7,4,10,2,7,8,7,0,2,0,7,-1,
    3,7,10,3,10,2,7,4,10,1,10,0,4,0,10,-1,
    1,10,2,8,7,4,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
    4,9,1,4,1,7,7,1,3,-1,-1,-1,-1,-1,-1,-1,
    4,9,1,4,1,7,0,8,1,8,7,1,-1,-1,-1,-1,
    4,0,3,7,4,3,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
    4,8,7,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
    9,10,8,10,11,8,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
    3,0,9,3,9,11,11,9,10,-1,-1,-1,-1,-1,-1,-1,
    0,1,10,0,10,8,8,10,11,-1,-1,-1,-1,-1,-1,-1,
    3,1,10,11,3,10,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
    1,2,11,1,11,9,9,11,8,-1,-1,-1,-1,-1,-1,-1,
    3,0,9,3,9,11,1,2,9,2,11,9,-1,-1,-1,-1,
    0,2,11,8,0,11,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
    3,2,11,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
    2,3,8,2,8,10,10,8,9,-1,-1,-1,-1,-1,-1,-1,
    9,10,2,0,9,2,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
    2,3,8,2,8,10,0,1,8,1,10,8,-1,-1,-1,-1,
    1,10,2,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
    1,3,8,9,1,8,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
    0,9,1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
    0,3,8,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
    -1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1
  };
  // clang-format on

  float target = 0.0f;

_INTR_INLINE ComputeCallRef createComputeCallPolygonization(
    std::unique_ptr<DynamicGeneratedMesh>& mesh, glm::vec3 p_Dim)
{
  ComputeCallRef computeCallMarchingCubesRef =
      ComputeCallManager::createComputeCall(_N(DynamicMeshGeneration));
  {
    ComputeCallManager::resetToDefault(computeCallMarchingCubesRef);
    ComputeCallManager::addResourceFlags(
        computeCallMarchingCubesRef, Dod::Resources::ResourceFlags::kResourceVolatile);
    ComputeCallManager::_descDimensions(computeCallMarchingCubesRef) = glm::uvec3(p_Dim);
    ComputeCallManager::_descPipeline(computeCallMarchingCubesRef) =
        mesh->_pipelinePolygonizationRef;

    ComputeCallManager::bindBuffer(computeCallMarchingCubesRef, _N(_PositionBuffer),
        GpuProgramType::kCompute, mesh->_positionBufferRef, UboType::kPerInstanceCompute,
        BufferManager::_descSizeInBytes(mesh->_positionBufferRef));
    ComputeCallManager::bindBuffer(computeCallMarchingCubesRef, _N(_NormalBuffer),
        GpuProgramType::kCompute, mesh->_normalBufferRef, UboType::kPerInstanceCompute,
        BufferManager::_descSizeInBytes(mesh->_normalBufferRef));
    ComputeCallManager::bindBuffer(computeCallMarchingCubesRef, _N(_BinormalBuffer),
        GpuProgramType::kCompute, mesh->_binormalBufferRef, UboType::kPerInstanceCompute,
        BufferManager::_descSizeInBytes(mesh->_binormalBufferRef));
    ComputeCallManager::bindBuffer(computeCallMarchingCubesRef, _N(_TangentBuffer),
        GpuProgramType::kCompute, mesh->_tangentBufferRef, UboType::kPerInstanceCompute,
        BufferManager::_descSizeInBytes(mesh->_tangentBufferRef));
    ComputeCallManager::bindBuffer(computeCallMarchingCubesRef, _N(_Uv0Buffer),
        GpuProgramType::kCompute, mesh->_uv0BufferRef, UboType::kPerInstanceCompute,
        BufferManager::_descSizeInBytes(mesh->_uv0BufferRef));
    ComputeCallManager::bindBuffer(computeCallMarchingCubesRef, _N(_ColorBuffer),
        GpuProgramType::kCompute, mesh->_colorBufferRef, UboType::kPerInstanceCompute,
        BufferManager::_descSizeInBytes(mesh->_colorBufferRef));
    ComputeCallManager::bindBuffer(computeCallMarchingCubesRef, _N(_CubeEdgeBuffer),
        GpuProgramType::kCompute, mesh->_cubeEdgeFlagsBufferRef, UboType::kPerInstanceCompute,
        BufferManager::_descSizeInBytes(mesh->_cubeEdgeFlagsBufferRef));
    ComputeCallManager::bindBuffer(computeCallMarchingCubesRef, _N(_TriangleConnectionBuffer),
        GpuProgramType::kCompute, mesh->_triangleConnectionBufferRef, UboType::kPerInstanceCompute,
        BufferManager::_descSizeInBytes(mesh->_triangleConnectionBufferRef));
    ComputeCallManager::bindBuffer(computeCallMarchingCubesRef, _N(_VoxelBuffer),
        GpuProgramType::kCompute, mesh->_voxelBufferRef, UboType::kPerInstanceCompute,
        BufferManager::_descSizeInBytes(mesh->_voxelBufferRef));
    ComputeCallManager::bindBuffer(computeCallMarchingCubesRef, _N(_DebugBuffer),
        GpuProgramType::kCompute, mesh->_debugBufferRef, UboType::kPerInstanceCompute,
        BufferManager::_descSizeInBytes(mesh->_debugBufferRef));
    ComputeCallManager::bindImage(computeCallMarchingCubesRef, _N(_NormalsTex),
        GpuProgramType::kCompute, mesh->_normalsImageRef, Samplers::kNearestRepeat);
    ComputeCallManager::bindBuffer(computeCallMarchingCubesRef, _N(_SizesBuffer),
        GpuProgramType::kCompute, mesh->_sizesBufferRef, UboType::kPerInstanceCompute,
        BufferManager::_descSizeInBytes(mesh->_sizesBufferRef));
    ComputeCallManager::bindBuffer(computeCallMarchingCubesRef, _N(_TargetBuffer),
        GpuProgramType::kCompute, mesh->_targetBufferRef, UboType::kPerInstanceCompute,
        BufferManager::_descSizeInBytes(mesh->_targetBufferRef));
  }
  return computeCallMarchingCubesRef;
}

_INTR_INLINE ComputeCallRef createComputeCallVoxelGeneration(
    std::unique_ptr<DynamicGeneratedMesh>& mesh, glm::vec3 p_Dim)
{
  ComputeCallRef computeCallVoxelGenerationRef =
      ComputeCallManager::createComputeCall(_N(VoxelGeneration));
  {
    ComputeCallManager::resetToDefault(computeCallVoxelGenerationRef);
    ComputeCallManager::addResourceFlags(
        computeCallVoxelGenerationRef, Dod::Resources::ResourceFlags::kResourceVolatile);
    ComputeCallManager::_descDimensions(computeCallVoxelGenerationRef) = glm::uvec3(p_Dim);
    ComputeCallManager::_descPipeline(computeCallVoxelGenerationRef) =
        mesh->_pipelineVoxelGenerationRef;

    ComputeCallManager::bindBuffer(computeCallVoxelGenerationRef, _N(_VoxelBuffer),
        GpuProgramType::kCompute, mesh->_voxelBufferRef, UboType::kPerInstanceCompute,
        BufferManager::_descSizeInBytes(mesh->_voxelBufferRef));
    ComputeCallManager::bindBuffer(computeCallVoxelGenerationRef, _N(_VoxelNormalBuffer),
        GpuProgramType::kCompute, mesh->_voxelNormalBufferRef, UboType::kPerInstanceCompute,
        BufferManager::_descSizeInBytes(mesh->_voxelNormalBufferRef));
    ComputeCallManager::bindImage(computeCallVoxelGenerationRef, _N(_Gradient3D),
        GpuProgramType::kCompute, mesh->_gradient3dImageRef, Samplers::kNearestRepeat);
    ComputeCallManager::bindImage(computeCallVoxelGenerationRef, _N(_PermTable2D),
        GpuProgramType::kCompute, mesh->_permTable2dImageRef, Samplers::kNearestRepeat);
    ComputeCallManager::bindBuffer(computeCallVoxelGenerationRef, _N(_SizeBuffer),
        GpuProgramType::kCompute, mesh->_sizesBufferRef, UboType::kPerInstanceCompute,
        BufferManager::_descSizeInBytes(mesh->_sizesBufferRef));
    ComputeCallManager::bindBuffer(computeCallVoxelGenerationRef, _N(_ParametersBuffer),
        GpuProgramType::kCompute, mesh->_noiseParametersRef, UboType::kPerInstanceCompute,
        BufferManager::_descSizeInBytes(mesh->_noiseParametersRef));
  }
  return computeCallVoxelGenerationRef;
}

_INTR_INLINE ComputeCallRef createComputeCallNormal(
    std::unique_ptr<DynamicGeneratedMesh>& mesh, glm::vec3 p_Dim)
{
  ComputeCallRef computeCallNormalRef =
      ComputeCallManager::createComputeCall(_N(NormalGeneration));
  {
    ComputeCallManager::resetToDefault(computeCallNormalRef);
    ComputeCallManager::addResourceFlags(
        computeCallNormalRef, Dod::Resources::ResourceFlags::kResourceVolatile);
    ComputeCallManager::_descDimensions(computeCallNormalRef) = glm::uvec3(p_Dim);
    ComputeCallManager::_descPipeline(computeCallNormalRef) = mesh->_pipelineNormalRef;

    ComputeCallManager::bindImage(computeCallNormalRef, _N(_NormalTex),
        GpuProgramType::kCompute, mesh->_normalsImageRef, Samplers::kNearestRepeat);
    ComputeCallManager::bindBuffer(computeCallNormalRef, _N(_NoiseBuffer),
        GpuProgramType::kCompute, mesh->_voxelBufferRef, UboType::kPerInstanceCompute,
        BufferManager::_descSizeInBytes(mesh->_voxelBufferRef));
    ComputeCallManager::bindBuffer(computeCallNormalRef, _N(_SizeBuffer),
        GpuProgramType::kCompute, mesh->_sizesBufferRef, UboType::kPerInstanceCompute,
        BufferManager::_descSizeInBytes(mesh->_sizesBufferRef));
  }
  return computeCallNormalRef;
}

  _INTR_INLINE static void updateDataMemory(void* p_Data, BufferRef bufferRef,
                                            uint32_t p_Size, uint32_t p_Offset)
  {
    memcpy((uint8_t*)BufferManager::getGpuMemory(bufferRef) + p_Offset, p_Data,
           p_Size);
  }
} // namespace

// Static members

std::vector<std::unique_ptr<DynamicGeneratedMesh>>
    DynamicMeshGeneration::dynamicGenerationMeshes;

std::vector<std::unique_ptr<Name>> pseudoInstancedMeshes;

void DynamicMeshGeneration::addDynamicGeneratedMesh(
    const int& sizeX, const int& sizeY, const int& sizeZ,
	const Name& meshName, const Name&& voxelGenerationShader,
    const Name&& normalGenerationShader, const Name&& geometryGenerationShader,
	bool isDynamic, float firstParam, float secondParam)
{
  std::unique_ptr<DynamicGeneratedMesh> dynamicGenerationMesh =
      std::make_unique<DynamicGeneratedMesh>(
          sizeX, sizeY, sizeZ,
          std::move(meshName), std::move(voxelGenerationShader),
          std::move(normalGenerationShader),
          std::move(geometryGenerationShader),
		  isDynamic, firstParam, secondParam);

  dynamicGenerationMeshes.push_back(std::move(dynamicGenerationMesh));
}

bool DynamicMeshGeneration::isOverridenMesh(const Name& meshName)
{
  for (auto& mesh : dynamicGenerationMeshes)
  {
    if ((*mesh->meshName) == meshName)
      return true;
  }
  return false;
}

bool DynamicMeshGeneration::isDynamicMesh(const Name& meshName)
{
  for (auto& mesh : dynamicGenerationMeshes)
  {
    if ((*mesh->meshName) == meshName)
      return mesh->isDynamic;
  }
  return false;
}

unsigned DynamicMeshGeneration::getIndicesNumber(const Name& meshName)
{
  for (auto& mesh : dynamicGenerationMeshes)
  {
    if ((*mesh->meshName) == meshName)
      return mesh->indicesNumber;
  }
  return 0u;
}

void DynamicMeshGeneration::init()
{
  BufferRefArray buffersToCreate;
  ImageRefArray imgsToCreate;

  for (auto& mesh : dynamicGenerationMeshes)
  {
    BufferRef _noiseParametersRef =
        BufferManager::createBuffer(_N(_ParametersBuffer));
    {
      BufferManager::resetToDefault(_noiseParametersRef);
      BufferManager::addResourceFlags(
          _noiseParametersRef, Dod::Resources::ResourceFlags::kResourceVolatile);
      BufferManager::_descBufferType(_noiseParametersRef) = BufferType::kStorage;
      BufferManager::_descMemoryPoolType(_noiseParametersRef) =
          MemoryPoolType::kStaticStagingBuffers;
      BufferManager::_descSizeInBytes(_noiseParametersRef) = sizeof(mesh->params);
      BufferManager::_descInitialData(_noiseParametersRef) = mesh->params;
    }
    mesh->_noiseParametersRef = _noiseParametersRef;
    buffersToCreate.push_back(_noiseParametersRef);

    BufferRef _voxelBufferRef = BufferManager::createBuffer(_N(_Voxels));
    {
      BufferManager::resetToDefault(_voxelBufferRef);
      BufferManager::addResourceFlags(
          _voxelBufferRef, Dod::Resources::ResourceFlags::kResourceVolatile);
      BufferManager::_descMemoryPoolType(_voxelBufferRef) =
          MemoryPoolType::kStaticStagingBuffers;
      BufferManager::_descBufferType(_voxelBufferRef) = BufferType::kStorage;
      BufferManager::_descSizeInBytes(_voxelBufferRef) =
          (*mesh->sizeX) * (*mesh->sizeY) * (*mesh->sizeZ) * sizeof(float);
    }
    mesh->_voxelBufferRef = _voxelBufferRef;
    buffersToCreate.push_back(_voxelBufferRef);

    BufferRef _voxelNormalBufferRef =
        BufferManager::createBuffer(_N(_VoxelNormals));
    {
      BufferManager::resetToDefault(_voxelNormalBufferRef);
      BufferManager::addResourceFlags(
          _voxelNormalBufferRef, Dod::Resources::ResourceFlags::kResourceVolatile);
      BufferManager::_descMemoryPoolType(_voxelNormalBufferRef) =
          MemoryPoolType::kStaticStagingBuffers;
      BufferManager::_descBufferType(_voxelNormalBufferRef) = BufferType::kStorage;
      BufferManager::_descSizeInBytes(_voxelNormalBufferRef) =
          (*mesh->sizeX) * (*mesh->sizeY) * (*mesh->sizeZ) * sizeof(float) * 4;
    }
    mesh->_voxelNormalBufferRef = _voxelNormalBufferRef;
    buffersToCreate.push_back(_voxelNormalBufferRef);

    BufferRef _sizesBufferRef = BufferManager::createBuffer(_N(_SizeBuffer));
    {
      BufferManager::resetToDefault(_sizesBufferRef);
      BufferManager::addResourceFlags(
          _sizesBufferRef, Dod::Resources::ResourceFlags::kResourceVolatile);
      BufferManager::_descBufferType(_sizesBufferRef) = BufferType::kStorage;
      BufferManager::_descSizeInBytes(_sizesBufferRef) = sizeof(mesh->sizes);
      BufferManager::_descInitialData(_sizesBufferRef) = mesh->sizes;
    }
    mesh->_sizesBufferRef = _sizesBufferRef;
    buffersToCreate.push_back(_sizesBufferRef);

    BufferRef _targetBufferRef = BufferManager::createBuffer(_N(_TargetBuffer));
    {
      BufferManager::resetToDefault(_targetBufferRef);
      BufferManager::addResourceFlags(
          _targetBufferRef, Dod::Resources::ResourceFlags::kResourceVolatile);
      BufferManager::_descBufferType(_targetBufferRef) = BufferType::kStorage;
      BufferManager::_descSizeInBytes(_targetBufferRef) = sizeof(float);
      BufferManager::_descInitialData(_targetBufferRef) = &target;
    }
    mesh->_targetBufferRef = _targetBufferRef;
    buffersToCreate.push_back(_targetBufferRef);

    BufferRef _cubeEdgeFlagsBufferRef =
        BufferManager::createBuffer(_N(_CubeEdgeFlags));
    {
      BufferManager::resetToDefault(_cubeEdgeFlagsBufferRef);
      BufferManager::addResourceFlags(
          _cubeEdgeFlagsBufferRef, Dod::Resources::ResourceFlags::kResourceVolatile);
      BufferManager::_descMemoryPoolType(_cubeEdgeFlagsBufferRef) =
          MemoryPoolType::kStaticStagingBuffers;
      BufferManager::_descBufferType(_cubeEdgeFlagsBufferRef) = BufferType::kStorage;
      BufferManager::_descSizeInBytes(_cubeEdgeFlagsBufferRef) = sizeof(cubeEdgeFlags);
      BufferManager::_descInitialData(_cubeEdgeFlagsBufferRef) = cubeEdgeFlags;
    }
    mesh->_cubeEdgeFlagsBufferRef = _cubeEdgeFlagsBufferRef;
    buffersToCreate.push_back(_cubeEdgeFlagsBufferRef);

    BufferRef _triangleConnectionBufferRef =
        BufferManager::createBuffer(_N(_TriangleConnectionTable));
    {
      BufferManager::resetToDefault(_triangleConnectionBufferRef);
      BufferManager::addResourceFlags(
          _triangleConnectionBufferRef, Dod::Resources::ResourceFlags::kResourceVolatile);
      BufferManager::_descBufferType(_triangleConnectionBufferRef) = BufferType::kStorage;
      BufferManager::_descSizeInBytes(_triangleConnectionBufferRef) =
          sizeof(triangleConnectionTable);
      BufferManager::_descInitialData(_triangleConnectionBufferRef) = triangleConnectionTable;
    }
    mesh->_triangleConnectionBufferRef = _triangleConnectionBufferRef;
    buffersToCreate.push_back(_triangleConnectionBufferRef);

    BufferRef _debugBufferRef = BufferManager::createBuffer(_N(_DebugBuffer));
    {
      BufferManager::resetToDefault(_debugBufferRef);
      BufferManager::addResourceFlags(
          _debugBufferRef, Dod::Resources::ResourceFlags::kResourceVolatile);
      BufferManager::_descBufferType(_debugBufferRef) = BufferType::kStorage;
      BufferManager::_descSizeInBytes(_debugBufferRef) = 150000 * 8 * sizeof(float);
    }
    mesh->_debugBufferRef = _debugBufferRef;
    buffersToCreate.push_back(_debugBufferRef);

    // Vertex attribute output buffers written by the polygonization compute shader.
    // Each slot holds up to 1 vertex; each voxel cube contributes up to 15 slots.
    const uint32_t maxSlots =
        (uint32_t)((*mesh->sizeX) * (*mesh->sizeY) * (*mesh->sizeZ)) * 15u;
    mesh->indicesNumber = maxSlots;

    BufferRef _positionBufferRef = BufferManager::createBuffer(_N(_PositionBuffer));
    {
      BufferManager::resetToDefault(_positionBufferRef);
      BufferManager::addResourceFlags(
          _positionBufferRef, Dod::Resources::ResourceFlags::kResourceVolatile);
      BufferManager::_descMemoryPoolType(_positionBufferRef) =
          MemoryPoolType::kStaticStagingBuffers;
      BufferManager::_descBufferType(_positionBufferRef) = BufferType::kStorage;
      BufferManager::_descSizeInBytes(_positionBufferRef) =
          maxSlots * 2u * sizeof(uint32_t);
    }
    mesh->_positionBufferRef = _positionBufferRef;
    buffersToCreate.push_back(_positionBufferRef);

    BufferRef _normalBufferRef = BufferManager::createBuffer(_N(_NormalBuffer));
    {
      BufferManager::resetToDefault(_normalBufferRef);
      BufferManager::addResourceFlags(
          _normalBufferRef, Dod::Resources::ResourceFlags::kResourceVolatile);
      BufferManager::_descMemoryPoolType(_normalBufferRef) =
          MemoryPoolType::kStaticStagingBuffers;
      BufferManager::_descBufferType(_normalBufferRef) = BufferType::kStorage;
      BufferManager::_descSizeInBytes(_normalBufferRef) =
          maxSlots * 2u * sizeof(uint32_t);
    }
    mesh->_normalBufferRef = _normalBufferRef;
    buffersToCreate.push_back(_normalBufferRef);

    BufferRef _binormalBufferRef = BufferManager::createBuffer(_N(_BinormalBuffer));
    {
      BufferManager::resetToDefault(_binormalBufferRef);
      BufferManager::addResourceFlags(
          _binormalBufferRef, Dod::Resources::ResourceFlags::kResourceVolatile);
      BufferManager::_descMemoryPoolType(_binormalBufferRef) =
          MemoryPoolType::kStaticStagingBuffers;
      BufferManager::_descBufferType(_binormalBufferRef) = BufferType::kStorage;
      BufferManager::_descSizeInBytes(_binormalBufferRef) =
          maxSlots * 2u * sizeof(uint32_t);
    }
    mesh->_binormalBufferRef = _binormalBufferRef;
    buffersToCreate.push_back(_binormalBufferRef);

    BufferRef _tangentBufferRef = BufferManager::createBuffer(_N(_TangentBuffer));
    {
      BufferManager::resetToDefault(_tangentBufferRef);
      BufferManager::addResourceFlags(
          _tangentBufferRef, Dod::Resources::ResourceFlags::kResourceVolatile);
      BufferManager::_descMemoryPoolType(_tangentBufferRef) =
          MemoryPoolType::kStaticStagingBuffers;
      BufferManager::_descBufferType(_tangentBufferRef) = BufferType::kStorage;
      BufferManager::_descSizeInBytes(_tangentBufferRef) =
          maxSlots * 2u * sizeof(uint32_t);
    }
    mesh->_tangentBufferRef = _tangentBufferRef;
    buffersToCreate.push_back(_tangentBufferRef);

    BufferRef _colorBufferRef = BufferManager::createBuffer(_N(_ColorBuffer));
    {
      BufferManager::resetToDefault(_colorBufferRef);
      BufferManager::addResourceFlags(
          _colorBufferRef, Dod::Resources::ResourceFlags::kResourceVolatile);
      BufferManager::_descMemoryPoolType(_colorBufferRef) =
          MemoryPoolType::kStaticStagingBuffers;
      BufferManager::_descBufferType(_colorBufferRef) = BufferType::kStorage;
      BufferManager::_descSizeInBytes(_colorBufferRef) =
          maxSlots * 2u * sizeof(uint32_t);
    }
    mesh->_colorBufferRef = _colorBufferRef;
    buffersToCreate.push_back(_colorBufferRef);

    BufferRef _uv0BufferRef = BufferManager::createBuffer(_N(_Uv0Buffer));
    {
      BufferManager::resetToDefault(_uv0BufferRef);
      BufferManager::addResourceFlags(
          _uv0BufferRef, Dod::Resources::ResourceFlags::kResourceVolatile);
      BufferManager::_descMemoryPoolType(_uv0BufferRef) =
          MemoryPoolType::kStaticStagingBuffers;
      BufferManager::_descBufferType(_uv0BufferRef) = BufferType::kStorage;
      BufferManager::_descSizeInBytes(_uv0BufferRef) = maxSlots * sizeof(uint32_t);
    }
    mesh->_uv0BufferRef = _uv0BufferRef;
    buffersToCreate.push_back(_uv0BufferRef);

    // Pre-existing noise/permutation images referenced by the voxel generation shader
    mesh->_gradient3dImageRef =
        ImageManager::getResourceByName(_N(gradient3d));
    mesh->_permTable2dImageRef =
        ImageManager::getResourceByName(_N(perm_table2d));

    ImageRef _normalsImageRef = ImageManager::createImage(_N(normalsTex));
    {
      ImageManager::resetToDefault(_normalsImageRef);
      ImageManager::addResourceFlags(
          _normalsImageRef, Dod::Resources::ResourceFlags::kResourceVolatile);

      // Fractal meshes use the full grid dimension; terrain-derived meshes use
      // sqrt(dim) because the normal compute dispatch is arranged differently.
      const Name& name = *(mesh->meshName);
      if (name != _N(pbr_test_0125) && name != _N(pbr_test_025) &&
          name != _N(house) && name != _N(skyscrapers) &&
          name != _N(village_houses) && name != _N(terrain_lava))
      {
        ImageManager::_descDimensions(_normalsImageRef) = glm::uvec3(
            sqrt(mesh->sizes[0]), sqrt(mesh->sizes[1]), sqrt(mesh->sizes[2]));
      }
      else
      {
        ImageManager::_descDimensions(_normalsImageRef) =
            glm::uvec3(mesh->sizes[0], mesh->sizes[1], mesh->sizes[2]);
      }
      ImageManager::_descImageFormat(_normalsImageRef) = Format::kR16G16B16A16Float;
      ImageManager::_descImageType(_normalsImageRef) = ImageType::kTexture;
      ImageManager::_descImageFlags(_normalsImageRef) =
          ImageFlags::kUsageSampled | ImageFlags::kUsageStorage;
    }
    mesh->_normalsImageRef = _normalsImageRef;
    imgsToCreate.push_back(_normalsImageRef);
  }

  BufferManager::createResources(buffersToCreate);
  ImageManager::createResources(imgsToCreate);

  // Transition normals images UNDEFINED→GENERAL for the first compute dispatch
  VkCommandBuffer initCmd = RenderSystem::beginTemporaryCommandBuffer();
  for (auto& mesh : dynamicGenerationMeshes)
  {
    ImageManager::insertImageMemoryBarrier(
        initCmd, mesh->_normalsImageRef,
        VK_IMAGE_LAYOUT_UNDEFINED, VK_IMAGE_LAYOUT_GENERAL,
        VK_PIPELINE_STAGE_TOP_OF_PIPE_BIT, VK_PIPELINE_STAGE_TOP_OF_PIPE_BIT);
  }
  RenderSystem::flushTemporaryCommandBuffer();
}

void DynamicMeshGeneration::postInit()
{
  PipelineRefArray pipelinesToCreate;
  PipelineLayoutRefArray pipelineLayoutsToCreate;
  ComputeCallRefArray computeCallsToCreate;

  for (auto& mesh : dynamicGenerationMeshes)
  {
    // Voxel/SDF generation pipeline
    PipelineLayoutRef pipelineLayoutVoxelGeneration =
        PipelineLayoutManager::createPipelineLayout(_N(VoxelGeneration));
    PipelineLayoutManager::resetToDefault(pipelineLayoutVoxelGeneration);
    GpuProgramManager::reflectPipelineLayout(
        1u, {GpuProgramManager::getResourceByName(*(mesh->shaders[0]))},
        pipelineLayoutVoxelGeneration);
    pipelineLayoutsToCreate.push_back(pipelineLayoutVoxelGeneration);

    PipelineRef _pipelineVoxelGenerationRef =
        PipelineManager::createPipeline(_N(VoxelGeneration));
    PipelineManager::resetToDefault(_pipelineVoxelGenerationRef);
    PipelineManager::_descComputeProgram(_pipelineVoxelGenerationRef) =
        GpuProgramManager::getResourceByName(*(mesh->shaders[0]));
    PipelineManager::_descPipelineLayout(_pipelineVoxelGenerationRef) =
        pipelineLayoutVoxelGeneration;
    mesh->_pipelineVoxelGenerationRef = _pipelineVoxelGenerationRef;
    pipelinesToCreate.push_back(_pipelineVoxelGenerationRef);

    // Normal generation pipeline
    PipelineLayoutRef pipelineLayoutNormal =
        PipelineLayoutManager::createPipelineLayout(_N(NormalGeneration));
    PipelineLayoutManager::resetToDefault(pipelineLayoutNormal);
    GpuProgramManager::reflectPipelineLayout(
        1u, {GpuProgramManager::getResourceByName(*(mesh->shaders[1]))},
        pipelineLayoutNormal);
    pipelineLayoutsToCreate.push_back(pipelineLayoutNormal);

    PipelineRef _pipelineNormalRef =
        PipelineManager::createPipeline(_N(NormalGeneration));
    PipelineManager::resetToDefault(_pipelineNormalRef);
    PipelineManager::_descComputeProgram(_pipelineNormalRef) =
        GpuProgramManager::getResourceByName(*(mesh->shaders[1]));
    PipelineManager::_descPipelineLayout(_pipelineNormalRef) = pipelineLayoutNormal;
    mesh->_pipelineNormalRef = _pipelineNormalRef;
    pipelinesToCreate.push_back(_pipelineNormalRef);

    // Polygonization (marching cubes) pipeline
    PipelineLayoutRef pipelineLayoutPolygonization =
        PipelineLayoutManager::createPipelineLayout(_N(DynamicMeshGeneration));
    PipelineLayoutManager::resetToDefault(pipelineLayoutPolygonization);
    GpuProgramManager::reflectPipelineLayout(
        1u, {GpuProgramManager::getResourceByName(*(mesh->shaders[2]))},
        pipelineLayoutPolygonization);
    pipelineLayoutsToCreate.push_back(pipelineLayoutPolygonization);

    PipelineRef _pipelinePolygonizationRef =
        PipelineManager::createPipeline(_N(DynamicMeshGeneration));
    PipelineManager::resetToDefault(_pipelinePolygonizationRef);
    PipelineManager::_descComputeProgram(_pipelinePolygonizationRef) =
        GpuProgramManager::getResourceByName(*(mesh->shaders[2]));
    PipelineManager::_descPipelineLayout(_pipelinePolygonizationRef) =
        pipelineLayoutPolygonization;
    mesh->_pipelinePolygonizationRef = _pipelinePolygonizationRef;
    pipelinesToCreate.push_back(_pipelinePolygonizationRef);

    PipelineLayoutManager::createResources(pipelineLayoutsToCreate);
    PipelineManager::createResources(pipelinesToCreate);

    const glm::uvec3 computeDim = glm::uvec3(
        sqrt(mesh->sizes[0]), sqrt(mesh->sizes[1]), sqrt(mesh->sizes[2]));

    ComputeCallRef _computeCallVoxelGenerationRef =
        createComputeCallVoxelGeneration(mesh, computeDim);
    mesh->_computeCallVoxelGenerationRef = _computeCallVoxelGenerationRef;
    computeCallsToCreate.push_back(_computeCallVoxelGenerationRef);

    ComputeCallRef _computeCallNormalRef =
        createComputeCallNormal(mesh, computeDim);
    mesh->_computeCallNormalRef = _computeCallNormalRef;
    computeCallsToCreate.push_back(_computeCallNormalRef);

    ComputeCallRef _computeCallMarchingCubesRef =
        createComputeCallPolygonization(mesh, computeDim);
    mesh->_computeCallMarchingCubesRef = _computeCallMarchingCubesRef;
    computeCallsToCreate.push_back(_computeCallMarchingCubesRef);
  }

  PipelineLayoutManager::createResources(pipelineLayoutsToCreate);
  PipelineManager::createResources(pipelinesToCreate);
  ComputeCallManager::createResources(computeCallsToCreate);
}

void DynamicMeshGeneration::onReinitRendering() {}

void DynamicMeshGeneration::destroy() {}

static void obfuscateMesh(DynamicGeneratedMesh& mesh)
{
  // Only count once, on the frame after the first compute dispatch completes.
  // beginFrame() uses per-swapchain-image fences, so the previous frame's GPU
  // work is not guaranteed done when we start recording the next frame.
  // vkQueueWaitIdle is a one-time cost that guarantees all submitted compute
  // writes are visible before we read the host-visible staging buffer.
  if (mesh.renderCounter != 1)
    return;

  vkQueueWaitIdle(RenderSystem::_vkQueue);

  // Position buffer is tightly packed half-floats: each vertex occupies
  // 3 × uint16 (x, y, z). A zero vertex has all three components == 0.
  const uint16_t* buf =
      (const uint16_t*)BufferManager::getGpuMemory(mesh._positionBufferRef);
  const uint32_t maxSlots = mesh.indicesNumber; // set to grid*15 in init()

  uint32_t vertexCount = 0u;
  for (uint32_t i = 0u; i < maxSlots; ++i)
  {
    if (buf[i * 3u] != 0u || buf[i * 3u + 1u] != 0u || buf[i * 3u + 2u] != 0u)
      ++vertexCount;
  }

  mesh.indicesNumber = vertexCount;
}

void DynamicMeshGeneration::render(float p_DeltaT, CameraRef p_CameraRef)
{
  _INTR_PROFILE_CPU("Render Pass", "Render Dynamic Mesh Generation");
  _INTR_PROFILE_GPU("Dynamic Mesh Generation");

  for (auto& mesh : dynamicGenerationMeshes)
  {
    if (!mesh->isDynamic && mesh->isCalled && mesh->renderCounter > 2)
      continue;

    VkCommandBuffer primaryCmdBuffer = RenderSystem::getPrimaryCommandBuffer();

    if (mesh->isCalled)
    {
      ImageManager::insertImageMemoryBarrier(mesh->_normalsImageRef,
          VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL, VK_IMAGE_LAYOUT_GENERAL,
          VK_PIPELINE_STAGE_COMPUTE_SHADER_BIT, VK_PIPELINE_STAGE_COMPUTE_SHADER_BIT);
    }

    // Stage 1: compute normals into the normals image (GENERAL→GENERAL self-barrier)
    RenderSystem::dispatchComputeCall(mesh->_computeCallNormalRef, primaryCmdBuffer);

    ImageManager::insertImageMemoryBarrier(mesh->_normalsImageRef,
        VK_IMAGE_LAYOUT_GENERAL, VK_IMAGE_LAYOUT_GENERAL,
        VK_PIPELINE_STAGE_COMPUTE_SHADER_BIT, VK_PIPELINE_STAGE_COMPUTE_SHADER_BIT);

    // Stage 2: fill the voxel SDF field
    RenderSystem::dispatchComputeCall(mesh->_computeCallVoxelGenerationRef,
                                      primaryCmdBuffer);

    BufferManager::insertBufferMemoryBarrier(mesh->_voxelBufferRef,
        VK_ACCESS_SHADER_WRITE_BIT, VK_ACCESS_SHADER_READ_BIT,
        VK_PIPELINE_STAGE_COMPUTE_SHADER_BIT, VK_PIPELINE_STAGE_COMPUTE_SHADER_BIT);
    BufferManager::insertBufferMemoryBarrier(mesh->_voxelNormalBufferRef,
        VK_ACCESS_SHADER_WRITE_BIT, VK_ACCESS_SHADER_READ_BIT,
        VK_PIPELINE_STAGE_COMPUTE_SHADER_BIT, VK_PIPELINE_STAGE_COMPUTE_SHADER_BIT);
    ImageManager::insertImageMemoryBarrier(mesh->_normalsImageRef,
        VK_IMAGE_LAYOUT_GENERAL, VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL,
        VK_PIPELINE_STAGE_COMPUTE_SHADER_BIT, VK_PIPELINE_STAGE_COMPUTE_SHADER_BIT);

    // Stage 3: polygonize with marching cubes → writes vertex attribute buffers
    RenderSystem::dispatchComputeCall(mesh->_computeCallMarchingCubesRef,
                                      primaryCmdBuffer);

    BufferManager::insertBufferMemoryBarrier(mesh->_positionBufferRef,
        VK_ACCESS_SHADER_WRITE_BIT, VK_ACCESS_VERTEX_ATTRIBUTE_READ_BIT,
        VK_PIPELINE_STAGE_COMPUTE_SHADER_BIT, VK_PIPELINE_STAGE_VERTEX_INPUT_BIT);
    BufferManager::insertBufferMemoryBarrier(mesh->_normalBufferRef,
        VK_ACCESS_SHADER_WRITE_BIT, VK_ACCESS_VERTEX_ATTRIBUTE_READ_BIT,
        VK_PIPELINE_STAGE_COMPUTE_SHADER_BIT, VK_PIPELINE_STAGE_VERTEX_INPUT_BIT);
    BufferManager::insertBufferMemoryBarrier(mesh->_binormalBufferRef,
        VK_ACCESS_SHADER_WRITE_BIT, VK_ACCESS_VERTEX_ATTRIBUTE_READ_BIT,
        VK_PIPELINE_STAGE_COMPUTE_SHADER_BIT, VK_PIPELINE_STAGE_VERTEX_INPUT_BIT);
    BufferManager::insertBufferMemoryBarrier(mesh->_tangentBufferRef,
        VK_ACCESS_SHADER_WRITE_BIT, VK_ACCESS_VERTEX_ATTRIBUTE_READ_BIT,
        VK_PIPELINE_STAGE_COMPUTE_SHADER_BIT, VK_PIPELINE_STAGE_VERTEX_INPUT_BIT);
    BufferManager::insertBufferMemoryBarrier(mesh->_uv0BufferRef,
        VK_ACCESS_SHADER_WRITE_BIT, VK_ACCESS_VERTEX_ATTRIBUTE_READ_BIT,
        VK_PIPELINE_STAGE_COMPUTE_SHADER_BIT, VK_PIPELINE_STAGE_VERTEX_INPUT_BIT);
    BufferManager::insertBufferMemoryBarrier(mesh->_colorBufferRef,
        VK_ACCESS_SHADER_WRITE_BIT, VK_ACCESS_VERTEX_ATTRIBUTE_READ_BIT,
        VK_PIPELINE_STAGE_COMPUTE_SHADER_BIT, VK_PIPELINE_STAGE_VERTEX_INPUT_BIT);

    obfuscateMesh(*mesh);

    mesh->isCalled = true;
    mesh->renderCounter++;

    const Name& name = *(mesh->meshName);

    if (name != _N(terrain_generated))
    {
      // Wire the compute-generated vertex buffers into the entity's draw call.
      Entity::EntityRef entityRef =
          Entity::EntityManager::getEntityByName(name);
      if (entityRef.isValid())
      {
        Components::MeshRef meshCompRef =
            Components::MeshManager::getComponentForEntity(entityRef);
        if (meshCompRef.isValid())
        {
          DrawCallArray& dcSets =
              Components::MeshManager::_drawCalls(meshCompRef);
          // Iterate over all material passes — GBufferDefault=1, Shadow=3,
          // PerPixelPicking=13, etc.  dcSets is indexed by material pass index.
          for (uint32_t passIdx = 0u; passIdx < dcSets.size(); ++passIdx)
          {
            for (uint32_t dcIdx = 0u; dcIdx < dcSets[passIdx].size(); ++dcIdx)
            {
              DrawCallRef dcRef = dcSets[passIdx][dcIdx];
              _INTR_ARRAY(VkBuffer)& vtxBuffers =
                  DrawCallManager::_vertexBuffers(dcRef);
              if (vtxBuffers.size() >= 6u)
              {
                // Binding order matches IntrinsicCoreResourcesMesh.cpp:
                // 0=position, 1=uv0, 2=normal, 3=tangent, 4=binormal, 5=color
                vtxBuffers[0] =
                    BufferManager::_vkBuffer(mesh->_positionBufferRef);
                vtxBuffers[1] =
                    BufferManager::_vkBuffer(mesh->_uv0BufferRef);
                vtxBuffers[2] =
                    BufferManager::_vkBuffer(mesh->_normalBufferRef);
                vtxBuffers[3] =
                    BufferManager::_vkBuffer(mesh->_tangentBufferRef);
                vtxBuffers[4] =
                    BufferManager::_vkBuffer(mesh->_binormalBufferRef);
                vtxBuffers[5] =
                    BufferManager::_vkBuffer(mesh->_colorBufferRef);
              }
              DrawCallManager::_descIndexBuffer(dcRef) = BufferRef();
              DrawCallManager::_descVertexCount(dcRef) = mesh->indicesNumber;
            }
          }
        }
      }
      continue;
    }

    PseudoInstancing::generateInstances();
  }
}

void DynamicMeshGeneration::update(const Name& name, const float& p_DeltaT)
{
  for (auto& mesh : dynamicGenerationMeshes)
  {
    if (*(mesh->meshName) != name)
      continue;

    mesh->params[0] += p_DeltaT * 1.0f;

    if (*(mesh->meshName) == _N(explosion_ep) && mesh->params[0] > 4.0)
      mesh->params[0] = 0.0;
    if (*(mesh->meshName) == _N(explosion_hp) && mesh->params[0] > 6.0)
      mesh->params[0] = 2.0;

    if (mesh->isDynamic && mesh->updateCounter % 1 == 0)
    {
      BufferRef buffer = mesh->_noiseParametersRef;
      updateDataMemory(mesh->params, buffer,
                       BufferManager::_descSizeInBytes(buffer), 0);
    }

    mesh->updateCounter++;
  }
}

void DynamicMeshGeneration::update(float p_DeltaT)
{
  for (auto& mesh : dynamicGenerationMeshes)
  {
    mesh->params[0] += p_DeltaT * 1.0f;

    if (*(mesh->meshName) == _N(explosion_ep) && mesh->params[0] > 4.0)
      mesh->params[0] = 0.0;
    if (*(mesh->meshName) == _N(explosion_hp) && mesh->params[0] > 6.0)
      mesh->params[0] = 2.0;

    if (mesh->isDynamic && mesh->updateCounter % 1 == 0)
    {
      BufferRef buffer = mesh->_noiseParametersRef;
      updateDataMemory(mesh->params, buffer,
                       BufferManager::_descSizeInBytes(buffer), 0);
    }

    mesh->updateCounter++;
  }
}

void DynamicMeshGeneration::moveEntities(const Name& name,
                                         const float& p_DeltaT,
                                         const float& offset)
{
  static std::random_device rd;
  static std::mt19937 mte(rd());
  std::uniform_real_distribution<float> dist(-100.0f, 100.0f);
  std::uniform_real_distribution<float> distCol(0.25f, 1.0f);
  std::bernoulli_distribution d(0.5);

  Entity::EntityRef entityRef = Entity::EntityManager::getEntityByName(name);
  NodeRef nodeRef = NodeManager::getComponentForEntity(entityRef);
  Components::MeshRef meshCompRef =
      Components::MeshManager::getComponentForEntity(entityRef);
  glm::vec3 size = NodeManager::getSize(nodeRef);

  if (!nodeRef.isValid())
    return;

  glm::vec3 position = NodeManager::getPosition(nodeRef);
  float offsetX = 0.0f;
  float offsetZ = 0.0f;

  for (auto& mesh : dynamicGenerationMeshes)
  {
    if (*(mesh->meshName) == name)
    {
      float& time = mesh->params[0];
      if (time > 3.4f + offset)
      {
        time = offset;
        offsetX = dist(mte);
        offsetZ = dist(mte);
        mesh->params[1] = d(mte) ? 1.0f : -1.0f;
        Components::MeshManager::_descColorTint(meshCompRef) =
            glm::vec4(distCol(mte), distCol(mte), distCol(mte), 1.0f);
      }
      else
      {
        time += p_DeltaT;
      }

      position.y = (mesh->params[1] > 0.0f)
                       ? (time - offset - 1.0f) * size.x * 5.0f
                       : -10.0f * size.x;
    }

    BufferRef buffer = mesh->_noiseParametersRef;
    updateDataMemory(mesh->params, buffer,
                     BufferManager::_descSizeInBytes(buffer), 0);
  }

  position.x += offsetX;
  position.z += offsetZ;

  glm::vec3 rotation = glm::vec3(0.0f, 0.1f, 0.0f);
  glm::quat orientation = NodeManager::getOrientation(nodeRef);
  NodeManager::setOrientation(nodeRef, glm::rotate(orientation, rotation));
  NodeManager::setPosition(nodeRef, position);
  NodeManager::updateTransforms(nodeRef);
}

void DynamicMeshGeneration::aquireVoxelsAndNormals(DynamicGeneratedMesh& mesh)
{
  for (int x = 0; x < 64; x += 1)
    for (int y = 0; y < 64; y += 1)
      for (int z = 0; z < 64; z += 1)
      {
        float voxel  = getVoxel(mesh, x, y, z);
        float voxel1 = getVoxel(mesh, x, y + 1, z);

        if (voxel > 0.0f && voxel1 < 0.0f)
        {
          Voxel v;
          v.x = static_cast<float>(x);
          v.y = static_cast<float>(y);
          v.z = static_cast<float>(64 - z);
          PseudoInstancing::voxels.push_back(v);

          glm::vec3 nor = getNormal(mesh, x, y + 1, z);
          Voxel n;
          n.x = nor.x;
          n.y = nor.y;
          n.z = nor.z;
          PseudoInstancing::normals.push_back(n);
        }
      }
}

float DynamicMeshGeneration::getVoxel(DynamicGeneratedMesh& mesh,
                                      int x, int y, int z)
{
  int index = x * (*mesh.sizeY) * (*mesh.sizeZ) + y * (*mesh.sizeZ) + z;
  float* buf = (float*)BufferManager::getGpuMemory(mesh._voxelBufferRef);
  return buf[index];
}

glm::vec3 DynamicMeshGeneration::getNormal(DynamicGeneratedMesh& mesh,
                                           int x, int y, int z)
{
  int index = 4 * (x * (*mesh.sizeY) * (*mesh.sizeZ) + y * (*mesh.sizeZ) + z);
  float* buf = (float*)BufferManager::getGpuMemory(mesh._voxelNormalBufferRef);
  return glm::vec3(buf[index], buf[index + 1], buf[index + 2]);
}

} // namespace RenderPass
} // namespace Renderer
} // namespace Intrinsic
