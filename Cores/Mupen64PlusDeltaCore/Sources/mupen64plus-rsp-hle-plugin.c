//
//  mupen64plus-rsp-hle-plugin.c
//  Mupen64PlusDeltaCore
//
//  Created by Riley Testut on 2/1/20.
//  Copyright © 2020 Riley Testut. All rights reserved.
//

// Add RSP prefix to function names so they don't collide with Video plug-in functions.
#define PluginStartup(A, B, C) RSP_PluginStartup(A, B, C)
#define PluginShutdown(A) RSP_PluginShutdown(A)
#define PluginGetVersion(A, B, C, D, E) RSP_PluginGetVersion(A, B, C, D, E)
#define RomClosed(A) RSP_RomClosed(A)

#include "../Mupen64Plus/mupen64plus-rsp-hle/src/plugin.c"

#undef PluginStartup
#undef PluginShutdown
#undef PluginGetVersion
#undef RomClosed
