//
//  texcache.cpp
//  DSDeltaCore
//
//  Created by Riley Testut on 2/3/20.
//  Copyright © 2020 Riley Testut. All rights reserved.
//

// Rename TextureCache to prevent static library collision with N64's TextureCache.
#define TextureCache TextureCacheDS

#include "../../desmume/desmume/src/texcache.cpp"

// Include files that reference texcache.h.
#include "../../desmume/desmume/src/driver.cpp"
#include "../../desmume/desmume/src/render3D.cpp"
#include "../../desmume/desmume/src/rasterize.cpp"

#undef TextureCache
