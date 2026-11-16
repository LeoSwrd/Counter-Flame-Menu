// File: CounterFlameHack.mm (v4 - Core UnityEngine & UIKit Multi-Feature Suite)
// Target: Counter Flame (Unity IL2CPP - iOS arm64 E-Sign)
// All features built on verified UnityEngine core icalls & UIKit layers for 100% compatibility

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <QuartzCore/QuartzCore.h>
#import <dlfcn.h>
#import <stdint.h>
#import <math.h>

// ============================================================================
// 1. GLOBAL SETTINGS & VARIETY STATES
// ============================================================================
struct HackConfig {
    // Chams Settings
    bool  chamsEnabled   = true;
    int   chamsColorMode = 0; // 0: Kirmizi, 1: Yesil, 2: Mavi, 3: Mor, 4: Altin, 5: RGB Gokkusagi
    bool  chamsGhostMode = false; // Yari saydam X-Ray hayalet gorunumu
    bool  chamsWireframe = false; // Parlak dis hat / cull modu

    // Camera & Vision Settings
    int   fovMode        = 0; // 0: Normal, 1: 90°, 2: 110° (iPad), 3: 125° (Ultra), 4: 35° (Zoom)
    bool  wallPeekXRay   = false; // Duvar dibinden iceriyi gorme (NearClipPlane)
    bool  antiCamShake   = false; // Kamera titremesini sifirla
    bool  noFogFullbright = false; // Sis kaldirma ve parlak harita

    // Speed & TimeScale Settings
    int   speedMode      = 0; // 0: 1.0x, 1: 1.2x (Legit+Rapid), 2: 1.5x, 3: 2.0x, 4: 0.5x (SlowMo)

    // Crosshair & HUD Settings
    int   crosshairStyle = 1; // 0: Kapali, 1: Arti+Halka, 2: Nokta, 3: Cember, 4: Sniper Scope
    bool  crosshairRGB   = false;
    float crosshairSize  = 12.0f;
    bool  showFPSCounter = true;
} g_Cfg;

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

// Verified UnityEngine Core Function Pointers
typedef Il2CppArray* (*Object_FindObjectsOfType_t)(void* systemType);
typedef void*        (*Renderer_GetMaterial_t)(void* renderer);
typedef void*        (*Shader_Find_t)(void* nameStr);
typedef void         (*Material_SetShader_t)(void* material, void* shader);
typedef void         (*Material_SetInt_t)(void* material, void* nameStr, int value);
typedef void         (*Material_SetColor_t)(void* material, void* nameStr, Color color);

typedef void*        (*Camera_get_main_t)();
typedef void         (*Camera_set_fieldOfView_t)(void* cam, float fov);
typedef float        (*Camera_get_fieldOfView_t)(void* cam);
typedef void         (*Camera_set_nearClipPlane_t)(void* cam, float nearPlane);
typedef void*        (*Component_get_transform_t)(void* comp);
typedef void         (*Transform_set_localPosition_t)(void* transform, Vector3 pos);

typedef void         (*Time_set_timeScale_t)(float scale);
typedef void         (*RenderSettings_set_fog_t)(bool fog);
typedef void         (*RenderSettings_set_ambientLight_t)(Color color);

static Object_FindObjectsOfType_t        u_FindObjectsOfType = nullptr;
static Renderer_GetMaterial_t            u_GetMaterial       = nullptr;
static Shader_Find_t                     u_Shader_Find       = nullptr;
static Material_SetShader_t              u_SetShader         = nullptr;
static Material_SetInt_t                 u_SetInt            = nullptr;
static Material_SetColor_t               u_SetColor          = nullptr;

static Camera_get_main_t                 u_Camera_get_main   = nullptr;
static Camera_set_fieldOfView_t          u_Camera_set_fov    = nullptr;
static Camera_get_fieldOfView_t          u_Camera_get_fov    = nullptr;
static Camera_set_nearClipPlane_t        u_Camera_set_near   = nullptr;
static Component_get_transform_t         u_get_transform     = nullptr;
static Transform_set_localPosition_t     u_set_localPos      = nullptr;

static Time_set_timeScale_t              u_Time_set_scale    = nullptr;
static RenderSettings_set_fog_t          u_SetFog            = nullptr;
static RenderSettings_set_ambientLight_t u_SetAmbientLight   = nullptr;

static bool  g_EngineReady = false;
static float g_DefaultFOV  = 60.0f;

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

    // 1. Renderer & Material (Chams Engine)
    u_FindObjectsOfType = (Object_FindObjectsOfType_t)FindMethodPtr("UnityEngine", "Object", "FindObjectsOfType", 1);
    u_GetMaterial       = (Renderer_GetMaterial_t)FindMethodPtr("UnityEngine", "Renderer", "get_material", 0);
    if (!u_GetMaterial && fn_resolve_icall)
        u_GetMaterial = (Renderer_GetMaterial_t)fn_resolve_icall("UnityEngine.Renderer::GetMaterial()");

    u_Shader_Find       = (Shader_Find_t)FindMethodPtr("UnityEngine", "Shader", "Find", 1);
    u_SetShader         = (Material_SetShader_t)FindMethodPtr("UnityEngine", "Material", "set_shader", 1);
    u_SetInt            = (Material_SetInt_t)FindMethodPtr("UnityEngine", "Material", "SetInt", 2);
    u_SetColor          = (Material_SetColor_t)FindMethodPtr("UnityEngine", "Material", "SetColor", 2);

    // 2. Camera & Transform (FOV, Wall-Peek X-Ray, Anti-Shake)
    u_Camera_get_main = (Camera_get_main_t)FindMethodPtr("UnityEngine", "Camera", "get_main", 0);
    if (!u_Camera_get_main && fn_resolve_icall)
        u_Camera_get_main = (Camera_get_main_t)fn_resolve_icall("UnityEngine.Camera::get_main()");

    u_Camera_set_fov = (Camera_set_fieldOfView_t)FindMethodPtr("UnityEngine", "Camera", "set_fieldOfView", 1);
    if (!u_Camera_set_fov && fn_resolve_icall)
        u_Camera_set_fov = (Camera_set_fieldOfView_t)fn_resolve_icall("UnityEngine.Camera::set_fieldOfView(System.Single)");

    u_Camera_get_fov = (Camera_get_fieldOfView_t)FindMethodPtr("UnityEngine", "Camera", "get_fieldOfView", 0);
    if (!u_Camera_get_fov && fn_resolve_icall)
        u_Camera_get_fov = (Camera_get_fieldOfView_t)fn_resolve_icall("UnityEngine.Camera::get_fieldOfView()");

    u_Camera_set_near = (Camera_set_nearClipPlane_t)FindMethodPtr("UnityEngine", "Camera", "set_nearClipPlane", 1);
    if (!u_Camera_set_near && fn_resolve_icall)
        u_Camera_set_near = (Camera_set_nearClipPlane_t)fn_resolve_icall("UnityEngine.Camera::set_nearClipPlane(System.Single)");

    u_get_transform = (Component_get_transform_t)FindMethodPtr("UnityEngine", "Component", "get_transform", 0);
    if (!u_get_transform && fn_resolve_icall)
        u_get_transform = (Component_get_transform_t)fn_resolve_icall("UnityEngine.Component::get_transform()");

    u_set_localPos = (Transform_set_localPosition_t)FindMethodPtr("UnityEngine", "Transform", "set_localPosition", 1);

    // 3. Time & RenderSettings (Speedhack, Slow-Mo, No-Fog, Fullbright)
    u_Time_set_scale = (Time_set_timeScale_t)FindMethodPtr("UnityEngine", "Time", "set_timeScale", 1);
    if (!u_Time_set_scale && fn_resolve_icall)
        u_Time_set_scale = (Time_set_timeScale_t)fn_resolve_icall("UnityEngine.Time::set_timeScale(System.Single)");

    u_SetFog = (RenderSettings_set_fog_t)FindMethodPtr("UnityEngine", "RenderSettings", "set_fog", 1);
    if (!u_SetFog && fn_resolve_icall)
        u_SetFog = (RenderSettings_set_fog_t)fn_resolve_icall("UnityEngine.RenderSettings::set_fog(System.Boolean)");

    u_SetAmbientLight = (RenderSettings_set_ambientLight_t)FindMethodPtr("UnityEngine", "RenderSettings", "set_ambientLight", 1);

    g_EngineReady = true;
    return true;
}

// ============================================================================
// 3. CORE FEATURE IMPLEMENTATIONS (CHAMS VARIETIES, FOV, SPEED, X-RAY)
// ============================================================================
Color GetCurrentChamsColor(CFTimeInterval timestamp) {
    float alpha = g_Cfg.chamsGhostMode ? 0.42f : 1.0f;
    switch (g_Cfg.chamsColorMode) {
        case 0: return { 1.00f, 0.06f, 0.22f, alpha }; // Neon Kirmizi
        case 1: return { 0.05f, 1.00f, 0.35f, alpha }; // Neon Yesil
        case 2: return { 0.00f, 0.88f, 1.00f, alpha }; // Camgobegi (Cyan)
        case 3: return { 0.85f, 0.12f, 1.00f, alpha }; // Neon Mor
        case 4: return { 1.00f, 0.82f, 0.05f, alpha }; // Altin Sarisi
        case 5: {
            // Rainbow RGB Cycle
            float r = (sinf(timestamp * 3.0f) + 1.0f) * 0.5f;
            float g = (sinf(timestamp * 3.0f + 2.094f) + 1.0f) * 0.5f;
            float b = (sinf(timestamp * 3.0f + 4.188f) + 1.0f) * 0.5f;
            return { r, g, b, alpha };
        }
        default: return { 1.0f, 0.1f, 0.2f, alpha };
    }
}

void ApplyChamsVarieties(CFTimeInterval timestamp) {
    if (!g_Cfg.chamsEnabled || !InitUnityEngineAPI()) return;
    if (!u_FindObjectsOfType || !u_GetMaterial || !fn_string_new) return;

    static void* skinnedMeshType = nullptr;
    if (!skinnedMeshType) {
        skinnedMeshType = FindTypeObject("UnityEngine", "SkinnedMeshRenderer");
    }
    if (!skinnedMeshType) return;

    Il2CppArray* renderers = u_FindObjectsOfType(skinnedMeshType);
    if (!renderers || renderers->max_length == 0) return;

    static void* chamsShader = nullptr;
    if (!chamsShader && u_Shader_Find) {
        chamsShader = u_Shader_Find(fn_string_new("Hidden/Internal-Colored"));
    }

    void* strZTest    = fn_string_new("_ZTest");
    void* strZWrite   = fn_string_new("_ZWrite");
    void* strCull     = fn_string_new("_Cull");
    void* strColor    = fn_string_new("_Color");
    void* strSrcBlend = fn_string_new("_SrcBlend");
    void* strDstBlend = fn_string_new("_DstBlend");

    Color targetColor = GetCurrentChamsColor(timestamp);

    uintptr_t count = renderers->max_length;
    if (count > 128) count = 128;

    for (uintptr_t i = 0; i < count; i++) {
        void* renderer = renderers->vector[i];
        if (!renderer) continue;

        void* mat = u_GetMaterial(renderer);
        if (!mat) continue;

        if (chamsShader && u_SetShader) {
            u_SetShader(mat, chamsShader);
        }
        if (u_SetInt) {
            // 8 = Always (Wallhack through walls)
            u_SetInt(mat, strZTest, 8);
            u_SetInt(mat, strZWrite, g_Cfg.chamsGhostMode ? 0 : 1);
            // Cull mode: 0 = Off (Both sides), 1 = Front (Backface/Outline effect)
            u_SetInt(mat, strCull, g_Cfg.chamsWireframe ? 1 : 0);

            if (g_Cfg.chamsGhostMode) {
                // Standard Alpha Blending (SrcAlpha = 5, OneMinusSrcAlpha = 10)
                u_SetInt(mat, strSrcBlend, 5);
                u_SetInt(mat, strDstBlend, 10);
            }
        }
        if (u_SetColor) {
            u_SetColor(mat, strColor, targetColor);
        }
    }
}

void ApplyCameraAndEnvironmentFeatures() {
    if (!InitUnityEngineAPI()) return;

    // 1. Camera Features (FOV Changer, Wall-Peek X-Ray, Anti-Camera Shake)
    if (u_Camera_get_main) {
        void* cam = u_Camera_get_main();
        if (cam) {
            if (u_Camera_get_fov && g_DefaultFOV == 60.0f) {
                float currentFov = u_Camera_get_fov(cam);
                if (currentFov > 40.0f && currentFov < 85.0f) {
                    g_DefaultFOV = currentFov;
                }
            }

            if (u_Camera_set_fov && g_Cfg.fovMode > 0) {
                float targetFov = g_DefaultFOV;
                switch (g_Cfg.fovMode) {
                    case 1: targetFov = 90.0f;  break; // Genis Aci
                    case 2: targetFov = 110.0f; break; // iPad Pro Gorunumu
                    case 3: targetFov = 125.0f; break; // Ultra Genis
                    case 4: targetFov = 32.0f;  break; // Sniper Zoom (Durbun)
                }
                u_Camera_set_fov(cam, targetFov);
            }

            // Wall-Peek X-Ray: Pushing nearClipPlane forward clips walls directly in front of player
            if (u_Camera_set_near) {
                u_Camera_set_near(cam, g_Cfg.wallPeekXRay ? 2.2f : 0.05f);
            }

            // Anti-Camera Shake: Zero out local position jitter on main camera transform
            if (g_Cfg.antiCamShake && u_get_transform && u_set_localPos) {
                void* camTransform = u_get_transform(cam);
                if (camTransform) {
                    Vector3 zeroPos = { 0.0f, 0.0f, 0.0f };
                    u_set_localPos(camTransform, zeroPos);
                }
            }
        }
    }

    // 2. TimeScale / Speed Mode
    if (u_Time_set_scale) {
        float scale = 1.0f;
        switch (g_Cfg.speedMode) {
            case 0: scale = 1.00f; break;
            case 1: scale = 1.22f; break; // Legit Speed + Rapid Fire
            case 2: scale = 1.50f; break; // Fast Speed
            case 3: scale = 2.00f; break; // Turbo Speed
            case 4: scale = 0.50f; break; // Slow-Motion Matrix
        }
        u_Time_set_scale(scale);
    }

    // 3. No Fog & Fullbright Map
    if (g_Cfg.noFogFullbright) {
        if (u_SetFog) u_SetFog(false);
        if (u_SetAmbientLight) {
            Color brightWhite = { 0.95f, 0.95f, 0.98f, 1.0f };
            u_SetAmbientLight(brightWhite);
        }
    }
}

// ============================================================================
// 4. NATIVE iOS SCROLLABLE MOD MENU & MULTI-CROSSHAIR OVERLAY
// ============================================================================
@interface CFModMenuController : UIViewController
@property (nonatomic, strong) UIButton* floatingButton;
@property (nonatomic, strong) UIView* menuPanel;
@property (nonatomic, strong) UIScrollView* scrollView;
@property (nonatomic, strong) UILabel* fpsLabel;
@property (nonatomic, strong) CAShapeLayer* crosshairLayer;
@property (nonatomic, strong) CADisplayLink* displayLink;
@property (nonatomic, assign) int frameCounter;
@property (nonatomic, assign) CFTimeInterval lastFpsTime;
@property (nonatomic, assign) int fpsCount;
@end

@implementation CFModMenuController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor clearColor];

    // 1. Crosshair Layer
    self.crosshairLayer = [CAShapeLayer layer];
    self.crosshairLayer.frame = [UIScreen mainScreen].bounds;
    self.crosshairLayer.strokeColor = [UIColor colorWithRed:0.0 green:1.0 blue:0.45 alpha:0.95].CGColor;
    self.crosshairLayer.fillColor = [UIColor clearColor].CGColor;
    self.crosshairLayer.lineWidth = 1.8f;
    [self.view.layer addSublayer:self.crosshairLayer];

    // 2. Live FPS Badge at Top-Center
    self.fpsLabel = [[UILabel alloc] initWithFrame:CGRectMake(120, 12, 140, 22)];
    self.fpsLabel.backgroundColor = [UIColor colorWithRed:0.05 green:0.05 blue:0.10 alpha:0.75];
    self.fpsLabel.textColor = [UIColor colorWithRed:0.0 green:1.0 blue:0.55 alpha:1.0];
    self.fpsLabel.font = [UIFont monospacedDigitSystemFontOfSize:11 weight:UIFontWeightBold];
    self.fpsLabel.textAlignment = NSTextAlignmentCenter;
    self.fpsLabel.layer.cornerRadius = 6;
    self.fpsLabel.layer.masksToBounds = YES;
    self.fpsLabel.text = @"CF v4 | 60 FPS";
    [self.view addSubview:self.fpsLabel];

    // 3. Draggable Floating Button
    self.floatingButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.floatingButton.frame = CGRectMake(40, 90, 56, 56);
    self.floatingButton.backgroundColor = [UIColor colorWithRed:0.08 green:0.05 blue:0.18 alpha:0.95];
    self.floatingButton.layer.cornerRadius = 28;
    self.floatingButton.layer.borderWidth = 2.2f;
    self.floatingButton.layer.borderColor = [UIColor colorWithRed:0.0 green:1.0 blue:0.55 alpha:1.0].CGColor;
    [self.floatingButton setTitle:@"CFv4" forState:UIControlStateNormal];
    self.floatingButton.titleLabel.font = [UIFont boldSystemFontOfSize:14];
    [self.floatingButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [self.floatingButton addTarget:self action:@selector(toggleMenu) forControlEvents:UIControlEventTouchUpInside];

    UIPanGestureRecognizer* pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handleDrag:)];
    [self.floatingButton addGestureRecognizer:pan];
    [self.view addSubview:self.floatingButton];

    // 4. Scrollable Mod Menu Panel
    self.menuPanel = [[UIView alloc] initWithFrame:CGRectMake(65, 45, 320, 310)];
    self.menuPanel.backgroundColor = [UIColor colorWithRed:0.05 green:0.05 blue:0.09 alpha:0.96];
    self.menuPanel.layer.cornerRadius = 14;
    self.menuPanel.layer.borderWidth = 1.6f;
    self.menuPanel.layer.borderColor = [UIColor colorWithRed:0.0 green:0.95 blue:0.55 alpha:0.85].CGColor;
    self.menuPanel.hidden = YES;

    UILabel* title = [[UILabel alloc] initWithFrame:CGRectMake(0, 8, 320, 24)];
    title.text = @"COUNTER FLAME v4 // VIP MENU";
    title.textColor = [UIColor colorWithRed:0.0 green:1.0 blue:0.55 alpha:1.0];
    title.font = [UIFont boldSystemFontOfSize:13];
    title.textAlignment = NSTextAlignmentCenter;
    [self.menuPanel addSubview:title];

    self.scrollView = [[UIScrollView alloc] initWithFrame:CGRectMake(0, 36, 320, 266)];
    self.scrollView.showsVerticalScrollIndicator = YES;
    [self.menuPanel addSubview:self.scrollView];

    CGFloat y = 6;

    // --- SECTION 1: CHAMS VARIETIES ---
    [self addSwitch:@"Wallhack Chams (Duvar Arkasi)" y:&y tag:1 initial:g_Cfg.chamsEnabled];
    [self addSegment:@"Chams Rengi" items:@[@"Kirmizi", @"Yesil", @"Mavi", @"Mor", @"Altin", @"RGB"] y:&y tag:10 selected:g_Cfg.chamsColorMode];
    [self addSwitch:@"Hayalet Chams (Yari Saydam X-Ray)" y:&y tag:2 initial:g_Cfg.chamsGhostMode];
    [self addSwitch:@"Ters Yuzey / Dis Hat Chams" y:&y tag:3 initial:g_Cfg.chamsWireframe];

    // --- SECTION 2: CAMERA & VISION ---
    [self addSegment:@"Kamera Acisi (FOV & Zoom)" items:@[@"Normal", @"90°", @"110° iPad", @"125°", @"Zoom"] y:&y tag:20 selected:g_Cfg.fovMode];
    [self addSwitch:@"Duvar Arkasi Kesici (Wall-Peek)" y:&y tag:4 initial:g_Cfg.wallPeekXRay];
    [self addSwitch:@"Kamera Titreme Kilidi (No Shake)" y:&y tag:5 initial:g_Cfg.antiCamShake];
    [self addSwitch:@"Sis Kaldir + Parlak Harita" y:&y tag:6 initial:g_Cfg.noFogFullbright];

    // --- SECTION 3: SPEED & TIMESCALE ---
    [self addSegment:@"Oyun & Ates Hizi (Speedhack)" items:@[@"1.0x", @"1.2x", @"1.5x", @"2.0x", @"0.5x Slow"] y:&y tag:30 selected:g_Cfg.speedMode];

    // --- SECTION 4: CROSSHAIR VARIETIES ---
    [self addSegment:@"Nisangah (Crosshair) Tipi" items:@[@"Kapali", @"Arti+", @"Nokta", @"Cember", @"Sniper"] y:&y tag:40 selected:g_Cfg.crosshairStyle];
    [self addSwitch:@"RGB Gokkusagi Crosshair" y:&y tag:7 initial:g_Cfg.crosshairRGB];
    [self addSwitch:@"Ustte Canli FPS Sayaci Goster" y:&y tag:8 initial:g_Cfg.showFPSCounter];

    self.scrollView.contentSize = CGSizeMake(320, y + 16);
    [self.view addSubview:self.menuPanel];

    self.lastFpsTime = CACurrentMediaTime();
    self.displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(renderTick:)];
    [self.displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
}

- (void)addSwitch:(NSString*)title y:(CGFloat*)y tag:(NSInteger)tag initial:(BOOL)val {
    UILabel* lbl = [[UILabel alloc] initWithFrame:CGRectMake(14, *y, 230, 28)];
    lbl.text = title;
    lbl.textColor = [UIColor whiteColor];
    lbl.font = [UIFont systemFontOfSize:12 weight:UIFontWeightMedium];
    [self.scrollView addSubview:lbl];

    UISwitch* sw = [[UISwitch alloc] initWithFrame:CGRectMake(252, *y, 50, 28)];
    sw.on = val;
    sw.tag = tag;
    sw.onTintColor = [UIColor colorWithRed:0.0 green:0.85 blue:0.45 alpha:1.0];
    [sw addTarget:self action:@selector(onSwitch:) forControlEvents:UIControlEventValueChanged];
    [self.scrollView addSubview:sw];

    *y += 36;
}

- (void)addSegment:(NSString*)title items:(NSArray<NSString*>*)items y:(CGFloat*)y tag:(NSInteger)tag selected:(NSInteger)sel {
    UILabel* lbl = [[UILabel alloc] initWithFrame:CGRectMake(14, *y, 290, 18)];
    lbl.text = title;
    lbl.textColor = [UIColor colorWithRed:0.0 green:0.95 blue:0.55 alpha:1.0];
    lbl.font = [UIFont boldSystemFontOfSize:11];
    [self.scrollView addSubview:lbl];
    *y += 20;

    UISegmentedControl* seg = [[UISegmentedControl alloc] initWithItems:items];
    seg.frame = CGRectMake(12, *y, 296, 28);
    seg.selectedSegmentIndex = sel;
    seg.tag = tag;
    seg.backgroundColor = [UIColor colorWithWhite:0.15 alpha:1.0];
    seg.selectedSegmentTintColor = [UIColor colorWithRed:0.0 green:0.75 blue:0.42 alpha:1.0];
    [seg setTitleTextAttributes:@{NSForegroundColorAttributeName: [UIColor whiteColor], NSFontAttributeName: [UIFont boldSystemFontOfSize:10]} forState:UIControlStateNormal];
    [seg addTarget:self action:@selector(onSegment:) forControlEvents:UIControlEventValueChanged];
    [self.scrollView addSubview:seg];

    *y += 36;
}

- (void)onSwitch:(UISwitch*)sender {
    switch (sender.tag) {
        case 1: g_Cfg.chamsEnabled    = sender.isOn; break;
        case 2: g_Cfg.chamsGhostMode  = sender.isOn; break;
        case 3: g_Cfg.chamsWireframe  = sender.isOn; break;
        case 4: g_Cfg.wallPeekXRay    = sender.isOn; break;
        case 5: g_Cfg.antiCamShake    = sender.isOn; break;
        case 6: g_Cfg.noFogFullbright = sender.isOn; break;
        case 7: g_Cfg.crosshairRGB    = sender.isOn; break;
        case 8:
            g_Cfg.showFPSCounter = sender.isOn;
            self.fpsLabel.hidden = !sender.isOn;
            break;
    }
    ApplyCameraAndEnvironmentFeatures();
    ApplyChamsVarieties(CACurrentMediaTime());
}

- (void)onSegment:(UISegmentedControl*)sender {
    NSInteger idx = sender.selectedSegmentIndex;
    switch (sender.tag) {
        case 10: g_Cfg.chamsColorMode = (int)idx; break;
        case 20:
            g_Cfg.fovMode = (int)idx;
            if (idx == 0 && u_Camera_get_main && u_Camera_set_fov) {
                void* cam = u_Camera_get_main();
                if (cam) u_Camera_set_fov(cam, g_DefaultFOV);
            }
            break;
        case 30: g_Cfg.speedMode      = (int)idx; break;
        case 40: g_Cfg.crosshairStyle = (int)idx; break;
    }
    ApplyCameraAndEnvironmentFeatures();
    ApplyChamsVarieties(CACurrentMediaTime());
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
    self.fpsCount++;
    CFTimeInterval now = link.timestamp;

    // 1. Update Live FPS Badge every 0.5s
    if (now - self.lastFpsTime >= 0.5) {
        int currentFps = (int)round(self.fpsCount / (now - self.lastFpsTime));
        self.fpsLabel.text = [NSString stringWithFormat:@"CF v4 | %d FPS", currentFps];
        self.fpsCount = 0;
        self.lastFpsTime = now;
    }

    // 2. Apply Camera FOV, Wall-Peek, Speedhack & Anti-Shake every frame so game never overrides them
    ApplyCameraAndEnvironmentFeatures();

    // 3. Update Chams (every 6 frames in Rainbow mode for smooth RGB animation, or every 45 frames for static colors)
    int chamsInterval = (g_Cfg.chamsColorMode == 5) ? 6 : 45;
    if (self.frameCounter % chamsInterval == 0) {
        ApplyChamsVarieties(now);
    }

    // 4. Draw Selected Crosshair Style
    if (g_Cfg.crosshairStyle == 0) {
        self.crosshairLayer.path = NULL;
        return;
    }

    CGRect bounds = self.view.bounds;
    self.crosshairLayer.frame = bounds;
    self.fpsLabel.center = CGPointMake(bounds.size.width * 0.5f, 20.0f);

    if (g_Cfg.crosshairRGB) {
        CGFloat hue = fmod(now * 0.45, 1.0);
        self.crosshairLayer.strokeColor = [UIColor colorWithHue:hue saturation:1.0 brightness:1.0 alpha:0.95].CGColor;
    } else {
        self.crosshairLayer.strokeColor = [UIColor colorWithRed:0.0 green:1.0 blue:0.45 alpha:0.95].CGColor;
    }

    CGFloat cx = bounds.size.width * 0.5f;
    CGFloat cy = bounds.size.height * 0.5f;
    CGFloat sz = g_Cfg.crosshairSize;

    UIBezierPath* path = [UIBezierPath bezierPath];

    switch (g_Cfg.crosshairStyle) {
        case 1: // Arti (+) ve Merkez Halka
            [path moveToPoint:CGPointMake(cx - sz, cy)];
            [path addLineToPoint:CGPointMake(cx + sz, cy)];
            [path moveToPoint:CGPointMake(cx, cy - sz)];
            [path addLineToPoint:CGPointMake(cx, cy + sz)];
            [path addArcWithCenter:CGPointMake(cx, cy) radius:4.0f startAngle:0 endAngle:(CGFloat)(M_PI * 2.0) clockwise:YES];
            break;

        case 2: // Keskin Nokta (Dot + Mini Circle)
            [path addArcWithCenter:CGPointMake(cx, cy) radius:2.0f startAngle:0 endAngle:(CGFloat)(M_PI * 2.0) clockwise:YES];
            [path addArcWithCenter:CGPointMake(cx, cy) radius:3.5f startAngle:0 endAngle:(CGFloat)(M_PI * 2.0) clockwise:YES];
            break;

        case 3: // Taktiksel Cember (Circle + Gap Crosshair)
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

        case 4: // Tam Ekran Sniper Scope Cizgileri
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

// Pass-through window so game touches work without any interruption
@interface CFPassthroughWindow : UIWindow
@end

@implementation CFPassthroughWindow
- (UIView*)hitTest:(CGPoint)point withEvent:(UIEvent*)event {
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

// ============================================================================
// 5. DYLIB CONSTRUCTOR ENTRY POINT
// ============================================================================
__attribute__((constructor))
static void InitializeCounterFlameDylib() {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(4.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        AttachOverlayWindow();
        InitUnityEngineAPI();
        ApplyChamsVarieties(CACurrentMediaTime());
        ApplyCameraAndEnvironmentFeatures();
    });
}
