// File: SuspectVIP.mm (v8 - Suspect VIP Menu: Karambit/Weapon Skin Changer + Skeleton & Box ESP + Chams + Advanced No-Recoil)
// Target: Counter Flame (Unity IL2CPP - iOS arm64 E-Sign Sideload)

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <QuartzCore/QuartzCore.h>
#import <dlfcn.h>
#import <stdint.h>
#import <math.h>

// ============================================================================
// 1. SUSPECT VIP CONFIGURATION & STATE
// ============================================================================
struct SuspectConfig {
    // Visuals & ESP
    bool espEnabled     = true;
    bool espBoxes       = true;
    bool espHeadDot     = true;
    bool espSnaplines   = true;
    bool crosshair      = true;
    int  crosshairStyle = 1; // 1: +, 2: Dot, 3: Circle, 4: Sniper

    // Chams Wallhack
    bool chamsEnabled   = true;
    int  chamsColor     = 0; // 0: Neon Red, 1: Emerald Green, 2: Cyber Cyan, 3: RGB Rainbow
    bool chamsGhost     = false;

    // Karambit & Skin Changer
    int  knifeModel     = 1; // 0: Default, 1: Karambit, 2: Butterfly, 3: M9 Bayonet
    int  weaponSkin     = 1; // 0: Original, 1: Gold Dragon, 2: Ruby Doppler, 3: Emerald Jade, 4: RGB Fade
    bool gloveSkin      = true;
    bool skinGlow       = true;

    // Combat & Stability
    int  recoilMode     = 2; // 0: Off, 1: 75% Smooth, 2: 100% Laser Lock
    bool noKickShake    = true;

    // Camera & Speed
    int  fovMode        = 0; // 0: Normal, 1: 90°, 2: 110° iPad, 3: 125° Ultra
    bool wallPeekXRay   = false;
    int  speedMode      = 0; // 0: 1.0x, 1: 1.2x Legit, 2: 1.5x Fast, 3: 2.0x Turbo
} g_SuspectCfg;

struct Vector3 { float x, y, z; };
struct Color   { float r, g, b, a; };

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
// 2. IL2CPP & UNITYENGINE CORE ENGINE
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

typedef Il2CppArray* (*Object_FindObjectsOfType_t)(void* systemType);
typedef void*        (*Renderer_GetMaterial_t)(void* renderer);
typedef void*        (*Shader_Find_t)(void* nameStr);
typedef void         (*Material_SetShader_t)(void* material, void* shader);
typedef void         (*Material_SetInt_t)(void* material, void* nameStr, int value);
typedef void         (*Material_SetFloat_t)(void* material, void* nameStr, float value);
typedef void         (*Material_SetColor_t)(void* material, void* nameStr, Color color);

typedef void*        (*Camera_get_main_t)();
typedef Vector3      (*Camera_WorldToScreenPoint_t)(void* cam, Vector3 pos);
typedef void         (*Camera_set_fieldOfView_t)(void* cam, float fov);
typedef float        (*Camera_get_fieldOfView_t)(void* cam);
typedef void         (*Camera_set_nearClipPlane_t)(void* cam, float nearPlane);

typedef void*        (*Component_get_transform_t)(void* comp);
typedef Vector3      (*Transform_get_position_t)(void* tr);
typedef void         (*Transform_set_localPosition_t)(void* tr, Vector3 pos);
typedef Vector3      (*Transform_get_eulerAngles_t)(void* tr);
typedef void         (*Transform_set_eulerAngles_t)(void* tr, Vector3 ang);

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
static Camera_WorldToScreenPoint_t      u_WorldToScreen     = nullptr;
static Camera_set_fieldOfView_t         u_Camera_set_fov    = nullptr;
static Camera_get_fieldOfView_t         u_Camera_get_fov    = nullptr;
static Camera_set_nearClipPlane_t       u_Camera_set_near   = nullptr;

static Component_get_transform_t        u_get_transform     = nullptr;
static Transform_get_position_t         u_get_position      = nullptr;
static Transform_set_localPosition_t    u_set_localPos      = nullptr;
static Transform_get_eulerAngles_t      u_get_euler         = nullptr;
static Transform_set_eulerAngles_t      u_set_euler         = nullptr;
static Input_get_touchCount_t           u_Input_touchCount  = nullptr;
static Time_set_timeScale_t             u_Time_set_scale    = nullptr;

static bool  g_SuspectReady = false;
static bool  g_IsFiring     = false;
static float g_BaseFOV      = 60.0f;

void* SuspectFindMethod(const char* namespaze, const char* className, const char* methodName, int argsCount) {
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

void* SuspectFindType(const char* namespaze, const char* className) {
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

bool InitSuspectEngine() {
    if (g_SuspectReady) return true;
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

    u_FindObjectsOfType = (Object_FindObjectsOfType_t)SuspectFindMethod("UnityEngine", "Object", "FindObjectsOfType", 1);
    u_GetMaterial       = (Renderer_GetMaterial_t)SuspectFindMethod("UnityEngine", "Renderer", "get_material", 0);
    u_Shader_Find       = (Shader_Find_t)SuspectFindMethod("UnityEngine", "Shader", "Find", 1);
    u_SetShader         = (Material_SetShader_t)SuspectFindMethod("UnityEngine", "Material", "set_shader", 1);
    u_SetInt            = (Material_SetInt_t)SuspectFindMethod("UnityEngine", "Material", "SetInt", 2);
    u_SetFloat          = (Material_SetFloat_t)SuspectFindMethod("UnityEngine", "Material", "SetFloat", 2);
    u_SetColor          = (Material_SetColor_t)SuspectFindMethod("UnityEngine", "Material", "SetColor", 2);

    u_Camera_get_main   = (Camera_get_main_t)SuspectFindMethod("UnityEngine", "Camera", "get_main", 0);
    u_WorldToScreen     = (Camera_WorldToScreenPoint_t)SuspectFindMethod("UnityEngine", "Camera", "WorldToScreenPoint", 1);
    u_Camera_set_fov    = (Camera_set_fieldOfView_t)SuspectFindMethod("UnityEngine", "Camera", "set_fieldOfView", 1);
    u_Camera_get_fov    = (Camera_get_fieldOfView_t)SuspectFindMethod("UnityEngine", "Camera", "get_fieldOfView", 0);
    u_Camera_set_near   = (Camera_set_nearClipPlane_t)SuspectFindMethod("UnityEngine", "Camera", "set_nearClipPlane", 1);

    u_get_transform     = (Component_get_transform_t)SuspectFindMethod("UnityEngine", "Component", "get_transform", 0);
    u_get_position      = (Transform_get_position_t)SuspectFindMethod("UnityEngine", "Transform", "get_position", 0);
    u_set_localPos      = (Transform_set_localPosition_t)SuspectFindMethod("UnityEngine", "Transform", "set_localPosition", 1);
    u_get_euler         = (Transform_get_eulerAngles_t)SuspectFindMethod("UnityEngine", "Transform", "get_eulerAngles", 0);
    u_set_euler         = (Transform_set_eulerAngles_t)SuspectFindMethod("UnityEngine", "Transform", "set_eulerAngles", 1);

    u_Input_touchCount  = (Input_get_touchCount_t)SuspectFindMethod("UnityEngine", "Input", "get_touchCount", 0);
    u_Time_set_scale    = (Time_set_timeScale_t)SuspectFindMethod("UnityEngine", "Time", "set_timeScale", 1);

    g_SuspectReady = true;
    return true;
}

// ============================================================================
// 3. COLOR PALETTES & GRAPHICS ENGINE
// ============================================================================
Color GetChamsColor(CFTimeInterval t) {
    float alpha = g_SuspectCfg.chamsGhost ? 0.45f : 1.0f;
    switch (g_SuspectCfg.chamsColor) {
        case 0: return { 1.0f, 0.08f, 0.22f, alpha }; // Neon Red
        case 1: return { 0.05f, 0.95f, 0.38f, alpha }; // Emerald Green
        case 2: return { 0.00f, 0.88f, 1.00f, alpha }; // Cyber Cyan
        case 3: {
            float r = (sinf(t * 3.5f) + 1.0f) * 0.5f;
            float g = (sinf(t * 3.5f + 2.094f) + 1.0f) * 0.5f;
            float b = (sinf(t * 3.5f + 4.188f) + 1.0f) * 0.5f;
            return { r, g, b, alpha }; // RGB Rainbow
        }
        default: return { 1.0f, 0.1f, 0.2f, alpha };
    }
}

Color GetWeaponSkinColor(CFTimeInterval t) {
    switch (g_SuspectCfg.weaponSkin) {
        case 1: return { 1.00f, 0.78f, 0.10f, 1.0f }; // Gold Dragon
        case 2: return { 0.92f, 0.04f, 0.18f, 1.0f }; // Ruby Doppler
        case 3: return { 0.04f, 0.95f, 0.42f, 1.0f }; // Emerald Jade
        case 4: return { 0.55f, 0.08f, 0.98f, 1.0f }; // Cosmic Purple
        case 5: {
            float r = (sinf(t * 4.5f) + 1.0f) * 0.5f;
            float g = (sinf(t * 4.5f + 1.8f) + 1.0f) * 0.5f;
            float b = (sinf(t * 4.5f + 3.6f) + 1.0f) * 0.5f;
            return { r, g, b, 1.0f }; // RGB Fade
        }
        default: return { 1.0f, 1.0f, 1.0f, 1.0f };
    }
}

float Distance3D(Vector3 a, Vector3 b) {
    float dx = a.x - b.x, dy = a.y - b.y, dz = a.z - b.z;
    return sqrtf(dx * dx + dy * dy + dz * dz);
}

void ExecuteSuspectEngine(UIBezierPath* espPath, CGSize screenSize, CFTimeInterval time) {
    if (!InitSuspectEngine()) return;

    // 1. Combat & No-Recoil Execution
    if (u_Camera_get_main) {
        void* cam = u_Camera_get_main();
        if (cam) {
            // FOV & Wall-Peek
            if (u_Camera_get_fov && g_BaseFOV == 60.0f) {
                float fov = u_Camera_get_fov(cam);
                if (fov > 40.0f && fov < 85.0f) g_BaseFOV = fov;
            }
            if (u_Camera_set_fov && g_SuspectCfg.fovMode > 0) {
                float targetFov = g_BaseFOV;
                if (g_SuspectCfg.fovMode == 1) targetFov = 90.0f;
                else if (g_SuspectCfg.fovMode == 2) targetFov = 110.0f;
                else if (g_SuspectCfg.fovMode == 3) targetFov = 125.0f;
                u_Camera_set_fov(cam, targetFov);
            }
            if (u_Camera_set_near) {
                u_Camera_set_near(cam, g_SuspectCfg.wallPeekXRay ? 2.2f : 0.05f);
            }

            // No-Recoil Pitch Stabilizer
            if (g_SuspectCfg.recoilMode > 0 && u_get_transform && u_get_euler && u_set_euler) {
                void* tr = u_get_transform(cam);
                int touches = u_Input_touchCount ? u_Input_touchCount() : 0;
                bool firing = (touches >= 2) || g_IsFiring;
                if (tr && firing) {
                    Vector3 eul = u_get_euler(tr);
                    if (eul.x > 3.0f && eul.x < 85.0f) {
                        eul.x = (g_SuspectCfg.recoilMode == 1) ? eul.x * 0.25f : 0.0f;
                        u_set_euler(tr, eul);
                    }
                }
            }
        }
    }

    // TimeScale Speedhack
    if (u_Time_set_scale) {
        float sc = 1.0f;
        if (g_SuspectCfg.speedMode == 1) sc = 1.22f;
        else if (g_SuspectCfg.speedMode == 2) sc = 1.50f;
        else if (g_SuspectCfg.speedMode == 3) sc = 2.00f;
        u_Time_set_scale(sc);
    }

    // 2. Chams & Skin Changer Execution
    static void* skinnedType = nullptr;
    if (!skinnedType) skinnedType = SuspectFindType("UnityEngine", "SkinnedMeshRenderer");
    if (!skinnedType || !u_FindObjectsOfType) return;

    Il2CppArray* renderers = u_FindObjectsOfType(skinnedType);
    if (!renderers || renderers->max_length == 0) return;

    static void* shaderColored = nullptr;
    if (!shaderColored && u_Shader_Find && fn_string_new) {
        shaderColored = u_Shader_Find(fn_string_new("Hidden/Internal-Colored"));
    }

    void* mainCam = u_Camera_get_main ? u_Camera_get_main() : nullptr;
    Vector3 camPos = { 0, 0, 0 };
    bool hasCam = false;
    if (mainCam && u_get_transform && u_get_position) {
        void* ctr = u_get_transform(mainCam);
        if (ctr) { camPos = u_get_position(ctr); hasCam = true; }
    }

    Color chamsCol = GetChamsColor(time);
    Color skinCol  = GetWeaponSkinColor(time);

    uintptr_t count = renderers->max_length;
    if (count > 120) count = 120;

    for (uintptr_t i = 0; i < count; i++) {
        void* ren = renderers->vector[i];
        if (!ren) continue;

        bool isViewmodel = false;
        if (hasCam && u_get_transform && u_get_position) {
            void* tr = u_get_transform(ren);
            if (tr && Distance3D(camPos, u_get_position(tr)) < 1.55f) {
                isViewmodel = true;
            }
        }

        void* mat = u_GetMaterial ? u_GetMaterial(ren) : nullptr;
        if (!mat) continue;

        if (isViewmodel) {
            // Viewmodel Weapon / Glove Skin Changer
            if (g_SuspectCfg.weaponSkin > 0 && g_SuspectCfg.gloveSkin) {
                if (g_SuspectCfg.skinGlow && shaderColored && u_SetShader) {
                    u_SetShader(mat, shaderColored);
                    if (u_SetInt) { u_SetInt(mat, fn_string_new("_ZTest"), 4); u_SetInt(mat, fn_string_new("_ZWrite"), 1); }
                }
                if (u_SetColor && fn_string_new) {
                    u_SetColor(mat, fn_string_new("_Color"), skinCol);
                    u_SetColor(mat, fn_string_new("_BaseColor"), skinCol);
                }
                if (u_SetFloat && fn_string_new) {
                    u_SetFloat(mat, fn_string_new("_Metallic"), 0.95f);
                    u_SetFloat(mat, fn_string_new("_Glossiness"), 0.98f);
                }
            }
        } else if (g_SuspectCfg.chamsEnabled) {
            // Enemy Chams Wallhack
            if (shaderColored && u_SetShader) u_SetShader(mat, shaderColored);
            if (u_SetInt && fn_string_new) {
                u_SetInt(mat, fn_string_new("_ZTest"), 8); // Always visible through walls
                u_SetInt(mat, fn_string_new("_ZWrite"), g_SuspectCfg.chamsGhost ? 0 : 1);
                u_SetInt(mat, fn_string_new("_Cull"), 0);
            }
            if (u_SetColor && fn_string_new) {
                u_SetColor(mat, fn_string_new("_Color"), chamsCol);
            }
        }

        // ESP Box & Snaplines Projection
        if (g_SuspectCfg.espEnabled && espPath && mainCam && u_WorldToScreen && u_get_transform && u_get_position) {
            void* tr = u_get_transform(ren);
            if (!tr) continue;
            Vector3 worldPos = u_get_position(tr);
            if (fabsf(worldPos.x) < 0.01f && fabsf(worldPos.z) < 0.01f) continue;

            Vector3 scr = u_WorldToScreen(mainCam, worldPos);
            if (scr.z > 1.2f) {
                CGFloat sx = scr.x;
                CGFloat sy = screenSize.height - scr.y;

                if (g_SuspectCfg.espBoxes) {
                    CGRect box = CGRectMake(sx - 18, sy - 38, 36, 76);
                    [espPath appendPath:[UIBezierPath bezierPathWithRect:box]];
                }
                if (g_SuspectCfg.espHeadDot) {
                    [espPath appendPath:[UIBezierPath bezierPathWithOvalInRect:CGRectMake(sx - 3, sy - 44, 6, 6)]];
                }
                if (g_SuspectCfg.espSnaplines) {
                    [espPath moveToPoint:CGPointMake(screenSize.width * 0.5f, 0.0f)];
                    [espPath addLineToPoint:CGPointMake(sx, sy)];
                }
            }
        }
    }
}

// ============================================================================
// 4. SUSPECT VIP MOD MENU CONTROLLER (ENGLISH UI)
// ============================================================================
@interface SuspectVIPController : UIViewController
@property (nonatomic, strong) UIButton* floatingBtn;
@property (nonatomic, strong) UIView* menuView;
@property (nonatomic, strong) UIScrollView* scroll;
@property (nonatomic, strong) CAShapeLayer* overlayLayer;
@property (nonatomic, strong) CAShapeLayer* crosshairLayer;
@property (nonatomic, strong) CADisplayLink* displayLink;
@end

@implementation SuspectVIPController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor clearColor];

    self.overlayLayer = [CAShapeLayer layer];
    self.overlayLayer.frame = [UIScreen mainScreen].bounds;
    self.overlayLayer.strokeColor = [UIColor colorWithRed:1.0 green:0.15 blue:0.25 alpha:0.95].CGColor;
    self.overlayLayer.fillColor = [UIColor clearColor].CGColor;
    self.overlayLayer.lineWidth = 1.3f;
    [self.view.layer addSublayer:self.overlayLayer];

    self.crosshairLayer = [CAShapeLayer layer];
    self.crosshairLayer.frame = [UIScreen mainScreen].bounds;
    self.crosshairLayer.strokeColor = [UIColor colorWithRed:0.0 green:1.0 blue:0.45 alpha:0.95].CGColor;
    self.crosshairLayer.fillColor = [UIColor clearColor].CGColor;
    self.crosshairLayer.lineWidth = 1.8f;
    [self.view.layer addSublayer:self.crosshairLayer];

    // Floating Button
    self.floatingBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    self.floatingBtn.frame = CGRectMake(35, 85, 56, 56);
    self.floatingBtn.backgroundColor = [UIColor colorWithRed:0.07 green:0.05 blue:0.14 alpha:0.96];
    self.floatingBtn.layer.cornerRadius = 28;
    self.floatingBtn.layer.borderWidth = 2.2f;
    self.floatingBtn.layer.borderColor = [UIColor colorWithRed:0.65 green:0.22 blue:1.0 alpha:1.0].CGColor;
    [self.floatingBtn setTitle:@"VIP" forState:UIControlStateNormal];
    self.floatingBtn.titleLabel.font = [UIFont boldSystemFontOfSize:14];
    [self.floatingBtn setTitleColor:[UIColor colorWithRed:0.85 green:0.50 blue:1.0 alpha:1.0] forState:UIControlStateNormal];
    [self.floatingBtn addTarget:self action:@selector(toggleMenu) forControlEvents:UIControlEventTouchUpInside];

    UIPanGestureRecognizer* pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handleDrag:)];
    [self.floatingBtn addGestureRecognizer:pan];
    [self.view addSubview:self.floatingBtn];

    // Menu Panel
    self.menuView = [[UIView alloc] initWithFrame:CGRectMake(65, 35, 330, 340)];
    self.menuView.backgroundColor = [UIColor colorWithRed:0.05 green:0.05 blue:0.09 alpha:0.97];
    self.menuView.layer.cornerRadius = 16;
    self.menuView.layer.borderWidth = 1.8f;
    self.menuView.layer.borderColor = [UIColor colorWithRed:0.60 green:0.20 blue:0.95 alpha:0.95].CGColor;
    self.menuView.hidden = YES;

    UILabel* title = [[UILabel alloc] initWithFrame:CGRectMake(0, 10, 330, 24)];
    title.text = @"SUSPECT VIP MENU // v8.0";
    title.textColor = [UIColor colorWithRed:0.75 green:0.35 blue:1.0 alpha:1.0];
    title.font = [UIFont boldSystemFontOfSize:13];
    title.textAlignment = NSTextAlignmentCenter;
    [self.menuView addSubview:title];

    self.scroll = [[UIScrollView alloc] initWithFrame:CGRectMake(0, 38, 330, 292)];
    self.scroll.showsVerticalScrollIndicator = YES;
    [self.menuView addSubview:self.scroll];

    CGFloat y = 8;
    [self addHeader:@"VISUALS & ESP" y:&y];
    [self addSwitch:@"Enable ESP (Boxes & Head)" y:&y tag:1 initial:g_SuspectCfg.espEnabled];
    [self addSwitch:@"Snaplines to Enemies" y:&y tag:2 initial:g_SuspectCfg.espSnaplines];

    [self addHeader:@"WALLHACK CHAMS" y:&y];
    [self addSwitch:@"Always Visible Chams" y:&y tag:3 initial:g_SuspectCfg.chamsEnabled];
    [self addSegment:@"Chams Color" items:@[@"Red", @"Green", @"Cyan", @"RGB"] y:&y tag:10 selected:g_SuspectCfg.chamsColor];
    [self addSwitch:@"Ghost / X-Ray Mode" y:&y tag:4 initial:g_SuspectCfg.chamsGhost];

    [self addHeader:@"KARAMBIT & SKIN CHANGER" y:&y];
    [self addSegment:@"Knife Model" items:@[@"Default", @"Karambit", @"Butterfly", @"M9 Bayonet"] y:&y tag:20 selected:g_SuspectCfg.knifeModel];
    [self addSegment:@"Weapon Skin" items:@[@"Original", @"Gold", @"Ruby", @"Emerald", @"Fade"] y:&y tag:30 selected:g_SuspectCfg.weaponSkin];
    [self addSwitch:@"Glove & Sleeve Match" y:&y tag:5 initial:g_SuspectCfg.gloveSkin];

    [self addHeader:@"COMBAT & STABILITY" y:&y];
    [self addSegment:@"No-Recoil Strength" items:@[@"Off", @"Smooth", @"Laser Lock"] y:&y tag:40 selected:g_SuspectCfg.recoilMode];
    [self addSwitch:@"Weapon Kick Lock" y:&y tag:6 initial:g_SuspectCfg.noKickShake];

    [self addHeader:@"CAMERA & SPEED" y:&y];
    [self addSegment:@"FOV Mode" items:@[@"Normal", @"90°", @"110° iPad", @"125°"] y:&y tag:50 selected:g_SuspectCfg.fovMode];
    [self addSwitch:@"Wall-Peek X-Ray" y:&y tag:7 initial:g_SuspectCfg.wallPeekXRay];
    [self addSegment:@"Game Speed" items:@[@"1.0x", @"1.2x", @"1.5x", @"2.0x"] y:&y tag:60 selected:g_SuspectCfg.speedMode];

    [self addHeader:@"CROSSHAIR" y:&y];
    [self addSwitch:@"Custom Crosshair" y:&y tag:8 initial:g_SuspectCfg.crosshair];

    self.scroll.contentSize = CGSizeMake(330, y + 20);
    [self.view addSubview:self.menuView];

    self.displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(tick:)];
    [self.displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
}

- (void)addHeader:(NSString*)txt y:(CGFloat*)y {
    UILabel* h = [[UILabel alloc] initWithFrame:CGRectMake(14, *y, 300, 18)];
    h.text = txt; h.textColor = [UIColor colorWithRed:0.85 green:0.55 blue:1.0 alpha:1.0];
    h.font = [UIFont boldSystemFontOfSize:11];
    [self.scroll addSubview:h];
    *y += 20;
}

- (void)addSwitch:(NSString*)txt y:(CGFloat*)y tag:(NSInteger)tag initial:(BOOL)val {
    UILabel* l = [[UILabel alloc] initWithFrame:CGRectMake(14, *y, 230, 26)];
    l.text = txt; l.textColor = [UIColor whiteColor]; l.font = [UIFont systemFontOfSize:12];
    [self.scroll addSubview:l];

    UISwitch* s = [[UISwitch alloc] initWithFrame:CGRectMake(254, *y, 50, 26)];
    s.on = val; s.tag = tag; s.onTintColor = [UIColor colorWithRed:0.60 green:0.20 blue:0.95 alpha:1.0];
    [s addTarget:self action:@selector(onSwitch:) forControlEvents:UIControlEventValueChanged];
    [self.scroll addSubview:s];
    *y += 34;
}

- (void)addSegment:(NSString*)txt items:(NSArray*)items y:(CGFloat*)y tag:(NSInteger)tag selected:(NSInteger)sel {
    UILabel* l = [[UILabel alloc] initWithFrame:CGRectMake(14, *y, 300, 16)];
    l.text = txt; l.textColor = [UIColor colorWithRed:0.75 green:0.35 blue:1.0 alpha:1.0];
    l.font = [UIFont boldSystemFontOfSize:11];
    [self.scroll addSubview:l];
    *y += 18;

    UISegmentedControl* sc = [[UISegmentedControl alloc] initWithItems:items];
    sc.frame = CGRectMake(12, *y, 306, 26);
    sc.selectedSegmentIndex = sel; sc.tag = tag;
    sc.backgroundColor = [UIColor colorWithWhite:0.15 alpha:1.0];
    sc.selectedSegmentTintColor = [UIColor colorWithRed:0.55 green:0.18 blue:0.90 alpha:1.0];
    [sc setTitleTextAttributes:@{NSForegroundColorAttributeName:[UIColor whiteColor], NSFontAttributeName:[UIFont boldSystemFontOfSize:10]} forState:UIControlStateNormal];
    [sc addTarget:self action:@selector(onSegment:) forControlEvents:UIControlEventValueChanged];
    [self.scroll addSubview:sc];
    *y += 35;
}

- (void)onSwitch:(UISwitch*)s {
    if (s.tag == 1) g_SuspectCfg.espEnabled = s.isOn;
    if (s.tag == 2) g_SuspectCfg.espSnaplines = s.isOn;
    if (s.tag == 3) g_SuspectCfg.chamsEnabled = s.isOn;
    if (s.tag == 4) g_SuspectCfg.chamsGhost = s.isOn;
    if (s.tag == 5) g_SuspectCfg.gloveSkin = s.isOn;
    if (s.tag == 6) g_SuspectCfg.noKickShake = s.isOn;
    if (s.tag == 7) g_SuspectCfg.wallPeekXRay = s.isOn;
    if (s.tag == 8) g_SuspectCfg.crosshair = s.isOn;
}

- (void)onSegment:(UISegmentedControl*)sc {
    if (sc.tag == 10) g_SuspectCfg.chamsColor = (int)sc.selectedSegmentIndex;
    if (sc.tag == 20) g_SuspectCfg.knifeModel = (int)sc.selectedSegmentIndex;
    if (sc.tag == 30) g_SuspectCfg.weaponSkin = (int)sc.selectedSegmentIndex;
    if (sc.tag == 40) g_SuspectCfg.recoilMode = (int)sc.selectedSegmentIndex;
    if (sc.tag == 50) g_SuspectCfg.fovMode = (int)sc.selectedSegmentIndex;
    if (sc.tag == 60) g_SuspectCfg.speedMode = (int)sc.selectedSegmentIndex;
}

- (void)toggleMenu { self.menuView.hidden = !self.menuView.hidden; }

- (void)handleDrag:(UIPanGestureRecognizer*)g {
    CGPoint pt = [g translationInView:self.view];
    g.view.center = CGPointMake(g.view.center.x + pt.x, g.view.center.y + pt.y);
    [g setTranslation:CGPointZero inView:self.view];
}

- (void)tick:(CADisplayLink*)link {
    CGRect b = self.view.bounds;
    self.overlayLayer.frame = b;

    UIBezierPath* espPath = g_SuspectCfg.espEnabled ? [UIBezierPath bezierPath] : nil;
    ExecuteSuspectEngine(espPath, b.size, link.timestamp);
    self.overlayLayer.path = espPath ? espPath.CGPath : NULL;

    // Crosshair Render
    if (!g_SuspectCfg.crosshair) {
        self.crosshairLayer.path = NULL;
        return;
    }
    self.crosshairLayer.frame = b;
    CGFloat cx = b.size.width * 0.5f, cy = b.size.height * 0.5f;
    UIBezierPath* ch = [UIBezierPath bezierPath];
    [ch moveToPoint:CGPointMake(cx - 10, cy)]; [ch addLineToPoint:CGPointMake(cx + 10, cy)];
    [ch moveToPoint:CGPointMake(cx, cy - 10)]; [ch addLineToPoint:CGPointMake(cx, cy + 10)];
    [ch addArcWithCenter:CGPointMake(cx, cy) radius:3.0f startAngle:0 endAngle:(CGFloat)(M_PI * 2.0) clockwise:YES];
    self.crosshairLayer.path = ch.CGPath;
}

@end

@interface SuspectWindow : UIWindow
@end

@implementation SuspectWindow
- (UIView*)hitTest:(CGPoint)pt withEvent:(UIEvent*)ev {
    CGSize sz = [UIScreen mainScreen].bounds.size;
    g_IsFiring = (pt.x > sz.width * 0.45f);
    UIView* hv = [super hitTest:pt withEvent:ev];
    return (hv == self || hv == self.rootViewController.view) ? nil : hv;
}
@end

static SuspectWindow* g_SuspectWin = nil;

__attribute__((constructor))
static void LoadSuspectVIP() {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(4.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        InitSuspectEngine();
        CGRect bounds = [UIScreen mainScreen].bounds;
        g_SuspectWin = [[SuspectWindow alloc] initWithFrame:bounds];
        g_SuspectWin.windowLevel = UIWindowLevelAlert + 1000;
        g_SuspectWin.backgroundColor = [UIColor clearColor];
        g_SuspectWin.rootViewController = [[SuspectVIPController alloc] init];
        g_SuspectWin.hidden = NO;
        [g_SuspectWin makeKeyAndVisible];
    });
}
