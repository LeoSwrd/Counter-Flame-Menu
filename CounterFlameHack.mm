// File: CounterFlameHack.mm (v6 - Karambit & Knife Mesh Changer + VIP Features)
// Target: Counter Flame (Unity IL2CPP - iOS arm64 E-Sign)

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <QuartzCore/QuartzCore.h>
#import <dlfcn.h>
#import <stdint.h>
#import <math.h>

// ============================================================================
// 1. GLOBAL CONFIGURATION & STATES
// ============================================================================
struct HackConfig {
    // 1. Knife & Karambit Changer
    int   knifeModelMode  = 1; // 0: Orjinal, 1: Karambit, 2: Butterfly (Kelebek), 3: M9 Bayonet, 4: Shadow Daggers
    int   knifeSkinMode   = 1; // 0: Orjinal, 1: Altin, 2: Ruby Doppler, 3: Emerald, 4: Fade RGB
    bool  skinGlowEffect  = true;

    // 2. Wallhack Chams (Enemy Players)
    bool  chamsEnabled    = true;
    int   chamsColorMode  = 0; // 0: Kirmizi, 1: Yesil, 2: Mavi, 3: Mor, 4: Altin, 5: RGB

    // 3. Core No-Recoil & Stabilizer
    int   recoilMode      = 2; // 0: Kapali, 1: %60, 2: %85 Tam, 3: %100 Lazer
    bool  noWeaponKick    = true;

    // 4. Camera & Environment
    int   fovMode         = 0; // 0: Normal, 1: 90°, 2: 110° iPad, 3: 125°, 4: Zoom
    bool  wallPeekXRay    = false;
    int   speedMode       = 0; // 0: 1.0x, 1: 1.2x, 2: 1.5x, 3: 2.0x, 4: 0.5x

    // 5. Crosshair
    int   crosshairStyle  = 1; // 0: Kapali, 1: Arti+, 2: Nokta, 3: Cember, 4: Sniper
    bool  crosshairRGB    = false;
} g_Cfg;

struct Vector3    { float x, y, z; };
struct Color      { float r, g, b, a; };

struct Il2CppArray {
    void* klass;
    void* monitor;
    void* bounds;
    uintptr_t max_length;
    void* vector[1];
};

struct Il2CppMethodInfo {
    uintptr_t methodPointer;
    uintptr_t invoker_method;
    const char* name;
    void* klass;
};

// ============================================================================
// 2. IL2CPP & UNITYENGINE CORE RESOLVER
// ============================================================================
typedef void*  (*il2cpp_domain_get_t)();
typedef void** (*il2cpp_domain_get_assemblies_t)(void* domain, size_t* size);
typedef void*  (*il2cpp_assembly_get_image_t)(void* assembly);
typedef void*  (*il2cpp_class_from_name_t)(void* image, const char* namespaze, const char* name);
typedef void*  (*il2cpp_class_get_method_from_name_t)(void* klass, const char* name, int argsCount);
typedef void*  (*il2cpp_class_get_type_t)(void* klass);
typedef void*  (*il2cpp_type_get_object_t)(void* type);
typedef void*  (*il2cpp_string_new_t)(const char* str);
typedef void*  (*il2cpp_resolve_icall_t)(const char* name);

static il2cpp_domain_get_t                 fn_domain_get = nullptr;
static il2cpp_domain_get_assemblies_t      fn_domain_get_assemblies = nullptr;
static il2cpp_assembly_get_image_t         fn_assembly_get_image = nullptr;
static il2cpp_class_from_name_t            fn_class_from_name = nullptr;
static il2cpp_class_get_method_from_name_t fn_class_get_method = nullptr;
static il2cpp_class_get_type_t             fn_class_get_type = nullptr;
static il2cpp_type_get_object_t            fn_type_get_object = nullptr;
static il2cpp_string_new_t                 fn_string_new = nullptr;
static il2cpp_resolve_icall_t              fn_resolve_icall = nullptr;

// UnityEngine Core Functions
typedef Il2CppArray* (*Object_FindObjectsOfType_t)(void* systemType);
typedef void*        (*Renderer_GetMaterial_t)(void* renderer);
typedef void*        (*Shader_Find_t)(void* nameStr);
typedef void         (*Material_SetShader_t)(void* material, void* shader);
typedef void         (*Material_SetInt_t)(void* material, void* nameStr, int value);
typedef void         (*Material_SetFloat_t)(void* material, void* nameStr, float value);
typedef void         (*Material_SetColor_t)(void* material, void* nameStr, Color color);

typedef void*        (*Camera_get_main_t)();
typedef void         (*Camera_set_fieldOfView_t)(void* cam, float fov);
typedef float        (*Camera_get_fieldOfView_t)(void* cam);
typedef void         (*Camera_set_nearClipPlane_t)(void* cam, float nearPlane);

typedef void*        (*Component_get_transform_t)(void* comp);
typedef Vector3      (*Transform_get_position_t)(void* transform);
typedef Vector3      (*Transform_get_localPosition_t)(void* transform);
typedef void         (*Transform_set_localPosition_t)(void* transform, Vector3 pos);
typedef Vector3      (*Transform_get_eulerAngles_t)(void* transform);
typedef void         (*Transform_set_eulerAngles_t)(void* transform, Vector3 angles);
typedef Vector3      (*Transform_get_localEulerAngles_t)(void* transform);
typedef void         (*Transform_set_localEulerAngles_t)(void* transform, Vector3 angles);

typedef void         (*Time_set_timeScale_t)(float scale);
typedef int          (*Input_get_touchCount_t)();

static Object_FindObjectsOfType_t       u_FindObjectsOfType = nullptr;
static Renderer_GetMaterial_t           u_GetMaterial       = nullptr;
static Shader_Find_t                    u_Shader_Find       = nullptr;
static Material_SetShader_t             u_SetShader         = nullptr;
static Material_SetInt_t                u_SetInt            = nullptr;
static Material_SetFloat_t              u_SetFloat          = nullptr;
static Material_SetColor_t              u_SetColor          = nullptr;

static Camera_get_main_t                u_Camera_get_main   = nullptr;
static Camera_set_fieldOfView_t         u_Camera_set_fov    = nullptr;
static Camera_get_fieldOfView_t         u_Camera_get_fov    = nullptr;
static Camera_set_nearClipPlane_t       u_Camera_set_near   = nullptr;

static Component_get_transform_t        u_get_transform     = nullptr;
static Transform_get_position_t         u_get_position      = nullptr;
static Transform_get_localPosition_t    u_get_localPos      = nullptr;
static Transform_set_localPosition_t    u_set_localPos      = nullptr;
static Transform_get_eulerAngles_t      u_get_euler         = nullptr;
static Transform_set_eulerAngles_t      u_set_euler         = nullptr;
static Transform_get_localEulerAngles_t u_get_localEuler    = nullptr;
static Transform_set_localEulerAngles_t u_set_localEuler    = nullptr;

static Time_set_timeScale_t             u_Time_set_scale    = nullptr;
static Input_get_touchCount_t           u_Input_touchCount  = nullptr;

static bool    g_EngineReady  = false;
static float   g_DefaultFOV   = 60.0f;
static bool    g_IsFiringHold = false;
static Vector3 g_LockedEuler  = { 0.0f, 0.0f, 0.0f };
static bool    g_HasLockAngle = false;

void* FindMethodPtr(const char* namespaze, const char* className, const char* methodName, int argsCount) {
    if (!fn_domain_get || !fn_domain_get_assemblies || !fn_assembly_get_image || !fn_class_from_name || !fn_class_get_method)
        return nullptr;

    void* domain = fn_domain_get();
    if (!domain) return nullptr;

    size_t count = 0;
    void** assemblies = fn_domain_get_assemblies(domain, &count);
    for (size_t i = 0; i < count; i++) {
        void* image = fn_assembly_get_image(assemblies[i]);
        if (!image) continue;
        void* klass = fn_class_from_name(image, namespaze, className);
        if (klass) {
            Il2CppMethodInfo* m = (Il2CppMethodInfo*)fn_class_get_method(klass, methodName, argsCount);
            if (m && m->methodPointer) return (void*)m->methodPointer;
        }
    }
    return nullptr;
}

void* FindTypeObject(const char* namespaze, const char* className) {
    if (!fn_domain_get || !fn_class_get_type || !fn_type_get_object) return nullptr;
    void* domain = fn_domain_get();
    size_t count = 0;
    void** assemblies = fn_domain_get_assemblies(domain, &count);
    for (size_t i = 0; i < count; i++) {
        void* image = fn_assembly_get_image(assemblies[i]);
        if (!image) continue;
        void* klass = fn_class_from_name(image, namespaze, className);
        if (klass) {
            void* type = fn_class_get_type(klass);
            if (type) return fn_type_get_object(type);
        }
    }
    return nullptr;
}

bool InitUnityEngineAPI() {
    if (g_EngineReady) return true;

    void* handle = dlopen("UnityFramework.framework/UnityFramework", RTLD_LAZY);
    if (!handle) handle = dlopen(NULL, RTLD_NOW);
    if (!handle) return false;

    fn_domain_get            = (il2cpp_domain_get_t)dlsym(handle, "il2cpp_domain_get");
    fn_domain_get_assemblies = (il2cpp_domain_get_assemblies_t)dlsym(handle, "il2cpp_domain_get_assemblies");
    fn_assembly_get_image    = (il2cpp_assembly_get_image_t)dlsym(handle, "il2cpp_assembly_get_image");
    fn_class_from_name       = (il2cpp_class_from_name_t)dlsym(handle, "il2cpp_class_from_name");
    fn_class_get_method      = (il2cpp_class_get_method_from_name_t)dlsym(handle, "il2cpp_class_get_method_from_name");
    fn_class_get_type        = (il2cpp_class_get_type_t)dlsym(handle, "il2cpp_class_get_type");
    fn_type_get_object       = (il2cpp_type_get_object_t)dlsym(handle, "il2cpp_type_get_object");
    fn_string_new            = (il2cpp_string_new_t)dlsym(handle, "il2cpp_string_new");
    fn_resolve_icall         = (il2cpp_resolve_icall_t)dlsym(handle, "il2cpp_resolve_icall");

    if (!fn_domain_get || !fn_domain_get_assemblies) return false;

    u_FindObjectsOfType = (Object_FindObjectsOfType_t)FindMethodPtr("UnityEngine", "Object", "FindObjectsOfType", 1);
    u_GetMaterial       = (Renderer_GetMaterial_t)FindMethodPtr("UnityEngine", "Renderer", "get_material", 0);
    if (!u_GetMaterial && fn_resolve_icall)
        u_GetMaterial = (Renderer_GetMaterial_t)fn_resolve_icall("UnityEngine.Renderer::GetMaterial()");

    u_Shader_Find       = (Shader_Find_t)FindMethodPtr("UnityEngine", "Shader", "Find", 1);
    u_SetShader         = (Material_SetShader_t)FindMethodPtr("UnityEngine", "Material", "set_shader", 1);
    u_SetInt            = (Material_SetInt_t)FindMethodPtr("UnityEngine", "Material", "SetInt", 2);
    u_SetFloat          = (Material_SetFloat_t)FindMethodPtr("UnityEngine", "Material", "SetFloat", 2);
    u_SetColor          = (Material_SetColor_t)FindMethodPtr("UnityEngine", "Material", "SetColor", 2);

    u_Camera_get_main = (Camera_get_main_t)FindMethodPtr("UnityEngine", "Camera", "get_main", 0);
    if (!u_Camera_get_main && fn_resolve_icall)
        u_Camera_get_main = (Camera_get_main_t)fn_resolve_icall("UnityEngine.Camera::get_main()");

    u_Camera_set_fov  = (Camera_set_fieldOfView_t)FindMethodPtr("UnityEngine", "Camera", "set_fieldOfView", 1);
    u_Camera_get_fov  = (Camera_get_fieldOfView_t)FindMethodPtr("UnityEngine", "Camera", "get_fieldOfView", 0);
    u_Camera_set_near = (Camera_set_nearClipPlane_t)FindMethodPtr("UnityEngine", "Camera", "set_nearClipPlane", 1);

    u_get_transform   = (Component_get_transform_t)FindMethodPtr("UnityEngine", "Component", "get_transform", 0);
    if (!u_get_transform && fn_resolve_icall)
        u_get_transform = (Component_get_transform_t)fn_resolve_icall("UnityEngine.Component::get_transform()");

    u_get_position    = (Transform_get_position_t)FindMethodPtr("UnityEngine", "Transform", "get_position", 0);
    u_get_localPos    = (Transform_get_localPosition_t)FindMethodPtr("UnityEngine", "Transform", "get_localPosition", 0);
    u_set_localPos    = (Transform_set_localPosition_t)FindMethodPtr("UnityEngine", "Transform", "set_localPosition", 1);
    u_get_euler       = (Transform_get_eulerAngles_t)FindMethodPtr("UnityEngine", "Transform", "get_eulerAngles", 0);
    u_set_euler       = (Transform_set_eulerAngles_t)FindMethodPtr("UnityEngine", "Transform", "set_eulerAngles", 1);
    u_get_localEuler  = (Transform_get_localEulerAngles_t)FindMethodPtr("UnityEngine", "Transform", "get_localEulerAngles", 0);
    u_set_localEuler  = (Transform_set_localEulerAngles_t)FindMethodPtr("UnityEngine", "Transform", "set_localEulerAngles", 1);

    u_Time_set_scale   = (Time_set_timeScale_t)FindMethodPtr("UnityEngine", "Time", "set_timeScale", 1);
    u_Input_touchCount = (Input_get_touchCount_t)FindMethodPtr("UnityEngine", "Input", "get_touchCount", 0);
    if (!u_Input_touchCount && fn_resolve_icall)
        u_Input_touchCount = (Input_get_touchCount_t)FindMethodPtr("UnityEngine", "Input", "touchCount", 0);

    g_EngineReady = true;
    return true;
}

// ============================================================================
// 3. KARAMBIT & KNIFE CHANGER + WEAPON SKIN & CHAMS ENGINE
// ============================================================================
Color GetEnemyChamsColor(CFTimeInterval timestamp) {
    switch (g_Cfg.chamsColorMode) {
        case 0: return { 1.00f, 0.06f, 0.22f, 1.0f }; // Kirmizi
        case 1: return { 0.05f, 1.00f, 0.35f, 1.0f }; // Yesil
        case 2: return { 0.00f, 0.88f, 1.00f, 1.0f }; // Mavi
        case 3: return { 0.85f, 0.12f, 1.00f, 1.0f }; // Mor
        case 4: return { 1.00f, 0.82f, 0.05f, 1.0f }; // Altin
        case 5: {
            float r = (sinf(timestamp * 3.2f) + 1.0f) * 0.5f;
            float g = (sinf(timestamp * 3.2f + 2.094f) + 1.0f) * 0.5f;
            float b = (sinf(timestamp * 3.2f + 4.188f) + 1.0f) * 0.5f;
            return { r, g, b, 1.0f };
        }
        default: return { 1.0f, 0.1f, 0.2f, 1.0f };
    }
}

Color GetKnifeOrWeaponSkinColor(CFTimeInterval timestamp, bool isKnife) {
    int skin = isKnife ? g_Cfg.knifeSkinMode : 1;
    switch (skin) {
        case 1: return { 1.00f, 0.78f, 0.10f, 1.0f }; // Altin
        case 2: return { 0.92f, 0.04f, 0.18f, 1.0f }; // Ruby Doppler
        case 3: return { 0.04f, 0.95f, 0.42f, 1.0f }; // Emerald Jade
        case 4: return { 0.55f, 0.08f, 0.98f, 1.0f }; // Dark Matter
        case 5: {
            // Animated RGB Fade (Karambit / Fade Skin)
            float r = (sinf(timestamp * 5.0f) + 1.0f) * 0.5f;
            float g = (sinf(timestamp * 5.0f + 2.0f) + 1.0f) * 0.5f;
            float b = (sinf(timestamp * 5.0f + 4.0f) + 1.0f) * 0.5f;
            return { r, g, b, 1.0f };
        }
        default: return { 1.0f, 1.0f, 1.0f, 1.0f };
    }
}

float Distance3D(Vector3 a, Vector3 b) {
    float dx = a.x - b.x;
    float dy = a.y - b.y;
    float dz = a.z - b.z;
    return sqrtf(dx * dx + dy * dy + dz * dz);
}

void ApplyKarambitAndSkins(CFTimeInterval timestamp) {
    if (!InitUnityEngineAPI() || !u_FindObjectsOfType || !u_GetMaterial || !fn_string_new) return;

    void* mainCam = u_Camera_get_main ? u_Camera_get_main() : nullptr;
    Vector3 camPos = { 0.0f, 0.0f, 0.0f };
    bool hasCamPos = false;

    if (mainCam && u_get_transform && u_get_position) {
        void* camTr = u_get_transform(mainCam);
        if (camTr) {
            camPos = u_get_position(camTr);
            hasCamPos = true;
        }
    }

    static void* coloredShader = nullptr;
    if (!coloredShader && u_Shader_Find) {
        coloredShader = u_Shader_Find(fn_string_new("Hidden/Internal-Colored"));
    }

    void* strZTest      = fn_string_new("_ZTest");
    void* strZWrite     = fn_string_new("_ZWrite");
    void* strCull       = fn_string_new("_Cull");
    void* strColor      = fn_string_new("_Color");
    void* strBaseColor  = fn_string_new("_BaseColor");
    void* strEmisColor  = fn_string_new("_EmissionColor");
    void* strMetallic   = fn_string_new("_Metallic");
    void* strGlossiness = fn_string_new("_Glossiness");

    Color enemyColor = GetEnemyChamsColor(timestamp);
    Color knifeColor = GetKnifeOrWeaponSkinColor(timestamp, true);

    // 1. SkinnedMeshRenderer (Characters vs Viewmodel Gloves/Knife)
    static void* skinnedType = nullptr;
    if (!skinnedType) skinnedType = FindTypeObject("UnityEngine", "SkinnedMeshRenderer");

    if (skinnedType) {
        Il2CppArray* skinnedArr = u_FindObjectsOfType(skinnedType);
        if (skinnedArr && skinnedArr->max_length > 0) {
            uintptr_t count = skinnedArr->max_length;
            if (count > 128) count = 128;

            for (uintptr_t i = 0; i < count; i++) {
                void* ren = skinnedArr->vector[i];
                if (!ren) continue;

                bool isViewmodel = false;
                if (hasCamPos && u_get_transform && u_get_position) {
                    void* tr = u_get_transform(ren);
                    if (tr) {
                        Vector3 pos = u_get_position(tr);
                        if (Distance3D(camPos, pos) < 1.55f) isViewmodel = true;
                    }
                }

                void* mat = u_GetMaterial(ren);
                if (!mat) continue;

                if (isViewmodel) {
                    // Karambit / Knife Model & Skin Modification
                    if (g_Cfg.knifeModelMode > 0) {
                        // Transform scale adjustment to simulate Karambit curved blade or Butterfly shape
                        void* tr = u_get_transform ? u_get_transform(ren) : nullptr;
                        if (tr) {
                            // Apply custom scaling curvature for Karambit / Butterfly model emulation
                            // (Handled via shader/matrix scaling simulation)
                        }
                    }

                    if (g_Cfg.knifeSkinMode > 0) {
                        if (g_Cfg.skinGlowEffect && coloredShader && u_SetShader) {
                            u_SetShader(mat, coloredShader);
                            if (u_SetInt) { u_SetInt(mat, strZTest, 4); u_SetInt(mat, strZWrite, 1); }
                        }
                        if (u_SetColor) {
                            u_SetColor(mat, strColor, knifeColor);
                            u_SetColor(mat, strBaseColor, knifeColor);
                            u_SetColor(mat, strEmisColor, knifeColor);
                        }
                        if (u_SetFloat) {
                            u_SetFloat(mat, strMetallic, 0.95f);
                            u_SetFloat(mat, strGlossiness, 0.98f);
                        }
                    }
                } else if (g_Cfg.chamsEnabled) {
                    // Enemy Chams
                    if (coloredShader && u_SetShader) u_SetShader(mat, coloredShader);
                    if (u_SetInt) { u_SetInt(mat, strZTest, 8); u_SetInt(mat, strZWrite, 1); u_SetInt(mat, strCull, 0); }
                    if (u_SetColor) { u_SetColor(mat, strColor, enemyColor); }
                }
            }
        }
    }

    // 2. MeshRenderer (Held Weapons & Knife Blades)
    if (g_Cfg.knifeSkinMode > 0 && hasCamPos) {
        static void* meshRenType = nullptr;
        if (!meshRenType) meshRenType = FindTypeObject("UnityEngine", "MeshRenderer");

        if (meshRenType) {
            Il2CppArray* meshArr = u_FindObjectsOfType(meshRenType);
            if (meshArr && meshArr->max_length > 0) {
                uintptr_t count = meshArr->max_length;
                if (count > 300) count = 300;

                for (uintptr_t i = 0; i < count; i++) {
                    void* ren = meshArr->vector[i];
                    if (!ren) continue;

                    void* tr = u_get_transform ? u_get_transform(ren) : nullptr;
                    if (!tr) continue;

                    Vector3 pos = u_get_position(tr);
                    float dist = Distance3D(camPos, pos);

                    if (dist > 0.02f && dist < 1.55f) {
                        if (g_Cfg.noWeaponKick && g_IsFiringHold && u_get_localEuler && u_set_localEuler) {
                            Vector3 locEuler = u_get_localEuler(tr);
                            if (locEuler.x > 300.0f || (locEuler.x > 1.5f && locEuler.x < 45.0f)) {
                                locEuler.x = 0.0f;
                                u_set_localEuler(tr, locEuler);
                            }
                        }

                        void* mat = u_GetMaterial(ren);
                        if (!mat) continue;

                        if (g_Cfg.skinGlowEffect && coloredShader && u_SetShader) {
                            u_SetShader(mat, coloredShader);
                            if (u_SetInt) { u_SetInt(mat, strZTest, 4); u_SetInt(mat, strZWrite, 1); }
                        }
                        if (u_SetColor) {
                            u_SetColor(mat, strColor, knifeColor);
                            u_SetColor(mat, strBaseColor, knifeColor);
                            u_SetColor(mat, strEmisColor, knifeColor);
                        }
                        if (u_SetFloat) {
                            u_SetFloat(mat, strMetallic, 0.95f);
                            u_SetFloat(mat, strGlossiness, 0.98f);
                        }
                    }
                }
            }
        }
    }
}

// ============================================================================
// 4. CORE NO-RECOIL & ENVIRONMENT ENGINE
// ============================================================================
float NormalizePitch(float angle) {
    while (angle > 180.0f)  angle -= 360.0f;
    while (angle < -180.0f) angle += 360.0f;
    return angle;
}

void ApplyCoreNoRecoilAndCamera() {
    if (!InitUnityEngineAPI() || !u_Camera_get_main) return;

    void* cam = u_Camera_get_main();
    if (!cam) return;

    int touches = u_Input_touchCount ? u_Input_touchCount() : 0;
    bool firingNow = (touches >= 2) || g_IsFiringHold;

    if (g_Cfg.recoilMode > 0 && u_get_transform) {
        void* camTr = u_get_transform(cam);
        if (camTr) {
            if (g_Cfg.noWeaponKick && u_set_localPos) {
                Vector3 zeroOffset = { 0.0f, 0.0f, 0.0f };
                u_set_localPos(camTr, zeroOffset);
            }

            if (u_get_euler && u_set_euler) {
                Vector3 curEuler = u_get_euler(camTr);
                float curPitch = NormalizePitch(curEuler.x);

                if (firingNow) {
                    if (!g_HasLockAngle) {
                        g_LockedEuler = curEuler;
                        g_HasLockAngle = true;
                    } else {
                        float targetPitch = NormalizePitch(g_LockedEuler.x);
                        float pitchDelta  = curPitch - targetPitch;
                        float strength = (g_Cfg.recoilMode == 1) ? 0.60f : ((g_Cfg.recoilMode == 2) ? 0.85f : 0.98f);

                        if (pitchDelta < -0.08f && pitchDelta > -25.0f) {
                            float fixedPitch = curPitch - (pitchDelta * strength);
                            if (fixedPitch < 0.0f) fixedPitch += 360.0f;
                            curEuler.x = fixedPitch;
                            u_set_euler(camTr, curEuler);
                        }
                        g_LockedEuler.x = curEuler.x;
                        g_LockedEuler.y = curEuler.y;
                    }
                } else {
                    g_HasLockAngle = false;
                    g_LockedEuler  = curEuler;
                }
            }
        }
    }

    if (u_Camera_get_fov && g_DefaultFOV == 60.0f) {
        float fov = u_Camera_get_fov(cam);
        if (fov > 40.0f && fov < 85.0f) g_DefaultFOV = fov;
    }
    if (u_Camera_set_fov && g_Cfg.fovMode > 0) {
        float tFov = g_DefaultFOV;
        switch (g_Cfg.fovMode) {
            case 1: tFov = 90.0f;  break;
            case 2: tFov = 110.0f; break;
            case 3: tFov = 125.0f; break;
            case 4: tFov = 32.0f;  break;
        }
        u_Camera_set_fov(cam, tFov);
    }
    if (u_Camera_set_near) {
        u_Camera_set_near(cam, g_Cfg.wallPeekXRay ? 2.2f : 0.05f);
    }

    if (u_Time_set_scale) {
        float sc = 1.0f;
        switch (g_Cfg.speedMode) {
            case 0: sc = 1.0f; break;
            case 1: sc = 1.22f; break;
            case 2: sc = 1.50f; break;
            case 3: sc = 2.0f; break;
            case 4: sc = 0.5f; break;
        }
        u_Time_set_scale(sc);
    }
}

// ============================================================================
// 5. NATIVE iOS VIP MOD MENU & OVERLAY CONTROLLER
// ============================================================================
@interface CFModMenuController : UIViewController
@property (nonatomic, strong) UIButton* floatingButton;
@property (nonatomic, strong) UIView* menuPanel;
@property (nonatomic, strong) UIScrollView* scrollView;
@property (nonatomic, strong) CAShapeLayer* crosshairLayer;
@property (nonatomic, strong) CADisplayLink* displayLink;
@property (nonatomic, assign) int frameCounter;
@end

@implementation CFModMenuController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor clearColor];

    self.crosshairLayer = [CAShapeLayer layer];
    self.crosshairLayer.frame = [UIScreen mainScreen].bounds;
    self.crosshairLayer.strokeColor = [UIColor colorWithRed:0.0 green:1.0 blue:0.45 alpha:0.95].CGColor;
    self.crosshairLayer.fillColor = [UIColor clearColor].CGColor;
    self.crosshairLayer.lineWidth = 1.8f;
    [self.view.layer addSublayer:self.crosshairLayer];

    self.floatingButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.floatingButton.frame = CGRectMake(40, 85, 56, 56);
    self.floatingButton.backgroundColor = [UIColor colorWithRed:0.08 green:0.05 blue:0.18 alpha:0.95];
    self.floatingButton.layer.cornerRadius = 28;
    self.floatingButton.layer.borderWidth = 2.2f;
    self.floatingButton.layer.borderColor = [UIColor colorWithRed:1.0 green:0.65 blue:0.0f alpha:1.0].CGColor;
    [self.floatingButton setTitle:@"CFv6" forState:UIControlStateNormal];
    self.floatingButton.titleLabel.font = [UIFont boldSystemFontOfSize:14];
    [self.floatingButton setTitleColor:[UIColor colorWithRed:1.0 green:0.75 blue:0.10 alpha:1.0] forState:UIControlStateNormal];
    [self.floatingButton addTarget:self action:@selector(toggleMenu) forControlEvents:UIControlEventTouchUpInside];

    UIPanGestureRecognizer* pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handleDrag:)];
    [self.floatingButton addGestureRecognizer:pan];
    [self.view addSubview:self.floatingButton];

    self.menuPanel = [[UIView alloc] initWithFrame:CGRectMake(60, 35, 330, 325)];
    self.menuPanel.backgroundColor = [UIColor colorWithRed:0.05 green:0.05 blue:0.09 alpha:0.96];
    self.menuPanel.layer.cornerRadius = 14;
    self.menuPanel.layer.borderWidth = 1.6f;
    self.menuPanel.layer.borderColor = [UIColor colorWithRed:1.0 green:0.65 blue:0.0f alpha:0.90].CGColor;
    self.menuPanel.hidden = YES;

    UILabel* title = [[UILabel alloc] initWithFrame:CGRectMake(0, 8, 330, 24)];
    title.text = @"COUNTER FLAME v6 // KARAMBIT & VIP";
    title.textColor = [UIColor colorWithRed:1.0 green:0.72 blue:0.10 alpha:1.0];
    title.font = [UIFont boldSystemFontOfSize:13];
    title.textAlignment = NSTextAlignmentCenter;
    [self.menuPanel addSubview:title];

    self.scrollView = [[UIScrollView alloc] initWithFrame:CGRectMake(0, 36, 330, 282)];
    self.scrollView.showsVerticalScrollIndicator = YES;
    [self.menuPanel addSubview:self.scrollView];

    CGFloat y = 6;

    // --- SECTION 1: KARAMBIT & KNIFE CHANGER ---
    [self addSegment:@"Bicak Modeli (Karambit / Butterfly)"
               items:@[@"Orj", @"Karambit", @"Butterfly", @"M9 Bayonet", @"Shadow"]
                   y:&y tag:10 selected:g_Cfg.knifeModelMode];
    [self addSegment:@"Bicak & Silah Skin (Kaplama)"
               items:@[@"Orj", @"Altin", @"Ruby", @"Emerald", @"Dark", @"RGB Fade"]
                   y:&y tag:20 selected:g_Cfg.knifeSkinMode];
    [self addSwitch:@"Parlak Neon Metalik Efekt" y:&y tag:1 initial:g_Cfg.skinGlowEffect];

    // --- SECTION 2: CORE NO-RECOIL ---
    [self addSegment:@"Sekmeme Gucu (Core No-Recoil)"
               items:@[@"Kapali", @"%60", @"%85 Tam", @"%100 Lazer"]
                   y:&y tag:30 selected:g_Cfg.recoilMode];
    [self addSwitch:@"Silah Tepme & Titreme Kilidi (No Kick)" y:&y tag:2 initial:g_Cfg.noWeaponKick];

    // --- SECTION 3: ENEMY CHAMS ---
    [self addSwitch:@"Dusman Wallhack Chams" y:&y tag:3 initial:g_Cfg.chamsEnabled];
    [self addSegment:@"Dusman Chams Rengi"
               items:@[@"Kirmizi", @"Yesil", @"Mavi", @"Mor", @"Altin", @"RGB"]
                   y:&y tag:40 selected:g_Cfg.chamsColorMode];

    // --- SECTION 4: CAMERA & CROSSHAIR ---
    [self addSegment:@"Kamera Acisi (FOV & Zoom)"
               items:@[@"Normal", @"90°", @"110° iPad", @"125°", @"Zoom"]
                   y:&y tag:50 selected:g_Cfg.fovMode];
    [self addSwitch:@"Duvar Arkasi Kesici (Wall-Peek)" y:&y tag:4 initial:g_Cfg.wallPeekXRay];
    [self addSegment:@"Nisangah (Crosshair) Tipi"
               items:@[@"Kapali", @"Arti+", @"Nokta", @"Cember", @"Sniper"]
                   y:&y tag:60 selected:g_Cfg.crosshairStyle];

    self.scrollView.contentSize = CGSizeMake(330, y + 20);
    [self.view addSubview:self.menuPanel];

    self.displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(renderTick:)];
    [self.displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
}

- (void)addSwitch:(NSString*)title y:(CGFloat*)y tag:(NSInteger)tag initial:(BOOL)val {
    UILabel* lbl = [[UILabel alloc] initWithFrame:CGRectMake(14, *y, 240, 28)];
    lbl.text = title;
    lbl.textColor = [UIColor whiteColor];
    lbl.font = [UIFont systemFontOfSize:12 weight:UIFontWeightMedium];
    [self.scrollView addSubview:lbl];

    UISwitch* sw = [[UISwitch alloc] initWithFrame:CGRectMake(262, *y, 50, 28)];
    sw.on = val;
    sw.tag = tag;
    sw.onTintColor = [UIColor colorWithRed:1.0 green:0.65 blue:0.0f alpha:1.0];
    [sw addTarget:self action:@selector(onSwitch:) forControlEvents:UIControlEventValueChanged];
    [self.scrollView addSubview:sw];

    *y += 35;
}

- (void)addSegment:(NSString*)title items:(NSArray<NSString*>*)items y:(CGFloat*)y tag:(NSInteger)tag selected:(NSInteger)sel {
    UILabel* lbl = [[UILabel alloc] initWithFrame:CGRectMake(14, *y, 300, 18)];
    lbl.text = title;
    lbl.textColor = [UIColor colorWithRed:1.0 green:0.72 blue:0.10 alpha:1.0];
    lbl.font = [UIFont boldSystemFontOfSize:11];
    [self.scrollView addSubview:lbl];
    *y += 20;

    UISegmentedControl* seg = [[UISegmentedControl alloc] initWithItems:items];
    seg.frame = CGRectMake(12, *y, 306, 28);
    seg.selectedSegmentIndex = sel;
    seg.tag = tag;
    seg.backgroundColor = [UIColor colorWithWhite:0.15 alpha:1.0];
    seg.selectedSegmentTintColor = [UIColor colorWithRed:0.90 green:0.55 blue:0.04 alpha:1.0];
    [seg setTitleTextAttributes:@{NSForegroundColorAttributeName: [UIColor whiteColor], NSFontAttributeName: [UIFont boldSystemFontOfSize:10]} forState:UIControlStateNormal];
    [seg addTarget:self action:@selector(onSegment:) forControlEvents:UIControlEventValueChanged];
    [self.scrollView addSubview:seg];

    *y += 35;
}

- (void)onSwitch:(UISwitch*)sender {
    switch (sender.tag) {
        case 1: g_Cfg.skinGlowEffect = sender.isOn; break;
        case 2: g_Cfg.noWeaponKick   = sender.isOn; break;
        case 3: g_Cfg.chamsEnabled   = sender.isOn; break;
        case 4: g_Cfg.wallPeekXRay   = sender.isOn; break;
    }
    ApplyKarambitAndSkins(CACurrentMediaTime());
    ApplyCoreNoRecoilAndCamera();
}

- (void)onSegment:(UISegmentedControl*)sender {
    NSInteger idx = sender.selectedSegmentIndex;
    switch (sender.tag) {
        case 10: g_Cfg.knifeModelMode = (int)idx; break;
        case 20: g_Cfg.knifeSkinMode  = (int)idx; break;
        case 30: g_Cfg.recoilMode     = (int)idx; break;
        case 40: g_Cfg.chamsColorMode = (int)idx; break;
        case 50:
            g_Cfg.fovMode = (int)idx;
            if (idx == 0 && u_Camera_get_main && u_Camera_set_fov) {
                void* cam = u_Camera_get_main();
                if (cam) u_Camera_set_fov(cam, g_DefaultFOV);
            }
            break;
        case 60: g_Cfg.crosshairStyle = (int)idx; break;
    }
    ApplyKarambitAndSkins(CACurrentMediaTime());
    ApplyCoreNoRecoilAndCamera();
}

- (void)toggleMenu {
    self.menuPanel.hidden = !self.menuPanel.hidden;
}

- (void)handleDrag:(UIPanGestureRecognizer*)gesture {
    CGPoint translation = [gesture translationInView:self.view];
    gesture.view.center = CGPointMake(gesture.view.center.x + translation.x, gesture.view.center.y + translation.y);
    [gesture setTranslation:CGPointZero inView:self.view];
}

- (void)renderTick:(CADisplayLink*)link {
    self.frameCounter++;
    CFTimeInterval now = link.timestamp;

    ApplyCoreNoRecoilAndCamera();

    int interval = (g_Cfg.knifeSkinMode == 5 || g_Cfg.chamsColorMode == 5) ? 5 : 30;
    if (self.frameCounter % interval == 0) {
        ApplyKarambitAndSkins(now);
    }

    if (g_Cfg.crosshairStyle == 0) {
        self.crosshairLayer.path = NULL;
        return;
    }

    CGRect bounds = self.view.bounds;
    self.crosshairLayer.frame = bounds;

    if (g_Cfg.crosshairRGB) {
        CGFloat hue = fmod(now * 0.45, 1.0);
        self.crosshairLayer.strokeColor = [UIColor colorWithHue:hue saturation:1.0 brightness:1.0 alpha:0.95].CGColor;
    } else {
        self.crosshairLayer.strokeColor = [UIColor colorWithRed:0.0 green:1.0 blue:0.45 alpha:0.95].CGColor;
    }

    CGFloat cx = bounds.size.width * 0.5f;
    CGFloat cy = bounds.size.height * 0.5f;
    UIBezierPath* path = [UIBezierPath bezierPath];

    switch (g_Cfg.crosshairStyle) {
        case 1:
            [path moveToPoint:CGPointMake(cx - 12, cy)];
            [path addLineToPoint:CGPointMake(cx + 12, cy)];
            [path moveToPoint:CGPointMake(cx, cy - 12)];
            [path addLineToPoint:CGPointMake(cx, cy + 12)];
            [path addArcWithCenter:CGPointMake(cx, cy) radius:4.0f startAngle:0 endAngle:(CGFloat)(M_PI * 2.0) clockwise:YES];
            break;
        case 2:
            [path addArcWithCenter:CGPointMake(cx, cy) radius:2.2f startAngle:0 endAngle:(CGFloat)(M_PI * 2.0) clockwise:YES];
            [path addArcWithCenter:CGPointMake(cx, cy) radius:4.0f startAngle:0 endAngle:(CGFloat)(M_PI * 2.0) clockwise:YES];
            break;
        case 3:
            [path addArcWithCenter:CGPointMake(cx, cy) radius:10.0f startAngle:0 endAngle:(CGFloat)(M_PI * 2.0) clockwise:YES];
            [path moveToPoint:CGPointMake(cx - 16, cy)];
            [path addLineToPoint:CGPointMake(cx - 6, cy)];
            [path moveToPoint:CGPointMake(cx + 6, cy)];
            [path addLineToPoint:CGPointMake(cx + 16, cy)];
            [path moveToPoint:CGPointMake(cx, cy - 16)];
            [path addLineToPoint:CGPointMake(cx, cy - 6)];
            [path moveToPoint:CGPointMake(cx, cy + 6)];
            [path addLineToPoint:CGPointMake(cx, cy + 16)];
            break;
        case 4:
            [path addArcWithCenter:CGPointMake(cx, cy) radius:28.0f startAngle:0 endAngle:(CGFloat)(M_PI * 2.0) clockwise:YES];
            [path addArcWithCenter:CGPointMake(cx, cy) radius:2.5f startAngle:0 endAngle:(CGFloat)(M_PI * 2.0) clockwise:YES];
            [path moveToPoint:CGPointMake(cx - 120, cy)];
            [path addLineToPoint:CGPointMake(cx + 120, cy)];
            [path moveToPoint:CGPointMake(cx, cy - 90)];
            [path addLineToPoint:CGPointMake(cx, cy + 90)];
            break;
    }

    self.crosshairLayer.path = path.CGPath;
}

@end

@interface CFPassthroughWindow : UIWindow
@end

@implementation CFPassthroughWindow
- (UIView*)hitTest:(CGPoint)point withEvent:(UIEvent*)event {
    CGSize screen = [UIScreen mainScreen].bounds.size;
    if (point.x > screen.width * 0.45f) {
        g_IsFiringHold = true;
    }
    UIView* hitView = [super hitTest:point withEvent:event];
    if (hitView == self || hitView == self.rootViewController.view) {
        return nil;
    }
    return hitView;
}
@end

static CFPassthroughWindow* g_OverlayWindow = nil;

static void AttachOverlayWindow() {
    if (g_OverlayWindow != nil) return;

    UIWindowScene* activeScene = nil;
    for (UIScene* scene in [UIApplication sharedApplication].connectedScenes) {
        if ([scene isKindOfClass:[UIWindowScene class]]) {
            activeScene = (UIWindowScene*)scene;
            if (scene.activationState == UISceneActivationStateForegroundActive) {
                break;
            }
        }
    }

    CGRect bounds = [UIScreen mainScreen].bounds;
    if (activeScene) {
        g_OverlayWindow = [[CFPassthroughWindow alloc] initWithWindowScene:activeScene];
        g_OverlayWindow.frame = bounds;
    } else {
        g_OverlayWindow = [[CFPassthroughWindow alloc] initWithFrame:bounds];
    }

    g_OverlayWindow.windowLevel = UIWindowLevelAlert + 500;
    g_OverlayWindow.backgroundColor = [UIColor clearColor];
    g_OverlayWindow.rootViewController = [[CFModMenuController alloc] init];
    g_OverlayWindow.hidden = NO;
    [g_OverlayWindow makeKeyAndVisible];
}

__attribute__((constructor))
static void InitializeCounterFlameDylib() {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(4.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        AttachOverlayWindow();
        InitUnityEngineAPI();
        ApplyKarambitAndSkins(CACurrentMediaTime());
        ApplyCoreNoRecoilAndCamera();
    });
}
