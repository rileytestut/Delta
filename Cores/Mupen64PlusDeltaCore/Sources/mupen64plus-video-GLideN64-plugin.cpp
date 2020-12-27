//
//  plugin_delta.c
//  N64DeltaCore-Video
//
//  Created by Riley Testut on 2/1/20.
//  Copyright © 2020 Riley Testut. All rights reserved.
//

// Add Video prefix to function names so they don't collide with RSP plug-in functions.
#define PluginStartup(A, ...) Video_PluginStartup(A, ## __VA_ARGS__)
#define PluginShutdown(A) Video_PluginShutdown(A)
#define PluginGetVersion(A, B, C, D, E) Video_PluginGetVersion(A, B, C, D, E)
#define RomOpen(A) Video_RomOpen(A)
#define RomClosed(A) Video_RomClosed(A)

// Explicitly include m64p_config.h _before_ renaming all Config functions so their header declarations remain the same.
#define M64P_CORE_PROTOTYPES
#include "../Mupen64Plus/mupen64plus-core/src/api/m64p_config.h"
#undef M64P_CORE_PROTOTYPES

#define ConfigGetSharedDataFilepath Video_ConfigGetSharedDataFilepath
#define ConfigGetUserConfigPath Video_ConfigGetUserConfigPath
#define ConfigGetUserDataPath Video_ConfigGetUserDataPath
#define ConfigGetUserCachePath Video_ConfigGetUserCachePath
#define ConfigOpenSection Video_ConfigOpenSection
#define ConfigDeleteSection Video_ConfigDeleteSection
#define ConfigSaveSection Video_ConfigSaveSection
#define ConfigSaveFile Video_ConfigSaveFile
#define ConfigSetParameter Video_ConfigSetParameter
#define ConfigGetParameter Video_ConfigGetParameter
#define ConfigGetParameterHelp Video_ConfigGetParameterHelp
#define ConfigSetDefaultInt Video_ConfigSetDefaultInt
#define ConfigSetDefaultFloat Video_ConfigSetDefaultFloat
#define ConfigSetDefaultBool Video_ConfigSetDefaultBool
#define ConfigSetDefaultString Video_ConfigSetDefaultString
#define ConfigGetParamInt Video_ConfigGetParamInt
#define ConfigGetParamFloat Video_ConfigGetParamFloat
#define ConfigGetParamBool Video_ConfigGetParamBool
#define ConfigGetParamString Video_ConfigGetParamString
#define ConfigExternalGetParameter Video_ConfigExternalGetParameter
#define ConfigExternalOpen Video_ConfigExternalOpen
#define ConfigExternalClose Video_ConfigExternalClose

#include "../Mupen64Plus/GLideN64/src/CommonPluginAPI.cpp"
#include "../Mupen64Plus/GLideN64/src/MupenPlusPluginAPI.cpp"
#include "../Mupen64Plus/GLideN64/src/common/CommonAPIImpl_common.cpp"

extern "C" m64p_function CALL osal_dynlib_getproc(m64p_dynlib_handle LibHandle, const char *pccProcedureName);

// Replace dlsym calls with our own osal_dynlib_getproc implementation.
#define dlsym(A, B) osal_dynlib_getproc(A, B)
#include "../Mupen64Plus/GLideN64/src/mupenplus/MupenPlusAPIImpl.cpp"
#undef dlsym

#undef ConfigGetSharedDataFilepath
#undef ConfigGetUserConfigPath
#undef ConfigGetUserDataPath
#undef ConfigGetUserCachePath
#undef ConfigOpenSection
#undef ConfigDeleteSection
#undef ConfigSaveSection
#undef ConfigSaveFile
#undef ConfigSetParameter
#undef ConfigGetParameter
#undef ConfigGetParameterHelp
#undef ConfigSetDefaultInt
#undef ConfigSetDefaultFloat
#undef ConfigSetDefaultBool
#undef ConfigSetDefaultString
#undef ConfigGetParamInt
#undef ConfigGetParamFloat
#undef ConfigGetParamBool
#undef ConfigGetParamString
#undef ConfigExternalGetParameter
#undef ConfigExternalOpen
#undef ConfigExternalClose

#undef PluginStartup
#undef PluginShutdown
#undef PluginGetVersion
#undef RomOpen
#undef RomClosed

#include "../Mupen64Plus/GLideN64/src/mupenplus/Config_mupenplus.cpp"
#include "../Mupen64Plus/GLideN64/src/mupenplus/CommonAPIImpl_mupenplus.cpp"
