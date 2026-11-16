// File: CounterFlameHack.mm (v2 - Full Active Engine)
// Target: Counter Flame (Unity IL2CPP - iOS arm64)
// Fixes: UIWindowScene attachment, Active SkinnedMeshRenderer Chams Loop, Auto-Assembly Class/Method Scanner

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <mach-o/dyld.h>
#import <mach/mach.h>
#import <libkern/OSCacheControl.h>
#import <dlfcn.h>
#import <stdint.h>
#import <vector>
#import <string>
#import <strings.h>

// ============================================================================
// 1. GLOBAL STATE & STRUCTURES
// ============================================================================
struct HackState {
    bool wallhackChams = true;
    bool crosshairESP  = true;
    bool zeroRecoil    = true;
    bool zeroSpread    = true;
    int  patchedCount  = 0;
} g_State;

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
// 2. JAILED iOS MEMORY PATCHER (MACH_VM_PROTECT)
// ============================================================================
bool PatchMemory(uintptr_t address, const uint8_t* bytes, size_t size) {
    if (!address || !bytes || size == 0) return false;
    mach_port_t task = mach_task_self();
    vm_address_t pageStart = (vm_address_t)(address & ~(vm_page_size - 1));
    vm_size_t pageSize = (vm_size_t)(((address + size - pageStart + vm_page_size - 1) / vm_page_size) * vm_page_size);

    kern_return_t kr = vm_protect(task, pageStart, pageSize, FALSE, VM_PROT_READ | VM_PROT_WRITE | VM_PROT_COPY);
    if (kr != KERN_SUCCESS) return false;

    memcpy((void*)address, bytes, size);
    vm_protect(task, pageStart, pageSize, FALSE, VM_PROT_READ | VM_PROT_EXECUTE);
    sys_icache_invalidate((void*)address, size);
    return true;
}

// ARM64 Instruction Patches
// FMOV S0, WZR ; RET -> Returns 0.0f
const uint8_t kPatchRetFloatZero[8] = { 0xE0, 0x03, 0x27, 0x1E, 0xC0, 0x03, 0x5F, 0xD6 };
// MOV W0, #0 ; RET -> Returns 0 / false
const uint8_t kPatchRetIntZero[8]   = { 0x00, 0x00, 0x80, 0x52, 0xC0, 0x03, 0x5F, 0xD6 };
// MOV W0, #1 ; RET -> Returns 1 / true
const uint8_t kPatchRetTrue[8]      = { 0x20, 0x00, 0x80, 0x52, 0xC0, 0x03, 0x5F, 0xD6 };
// RET -> NOPs void functions immediately
const uint8_t kPatchRetVoid[4]      = { 0xC0, 0x03, 0x5F, 0xD6 };

// ============================================================================
// 3. IL2CPP DYNAMIC SYMBOL & CLASS SCANNER
// ============================================================================
typedef void*       (*il2cpp_domain_get_t)();
typedef void**      (*il2cpp_domain_get_assemblies_t)(void* domain, size_t* size);
typedef void*       (*il2cpp_assembly_get_image_t)(void* assembly);
typedef size_t      (*il2cpp_image_get_class_count_t)(void* image);
typedef void*       (*il2cpp_image_get_class_t)(void* image, size_t index);
typedef void*       (*il2cpp_class_from_name_t)(void* image, const char* namespaze, const char* name);
typedef const char* (*il2cpp_class_get_name_t)(void* klass);
typedef void*       (*il2cpp_class_get_methods_t)(void* klass, void** iter);
typedef void*       (*il2cpp_class_get_method_from_name_t)(void* klass, const char* name, int argsCount);
typedef const char* (*il2cpp_method_get_name_t)(void* method);
typedef void*       (*il2cpp_class_get_type_t)(void* klass);
typedef void*       (*il2cpp_type_get_object_t)(void* type);
typedef void*       (*il2cpp_string_new_t)(const char* str);
typedef void*       (*il2cpp_resolve_icall_t)(const char* name);

static il2cpp_domain_get_t                 fn_domain_get = nullptr;
static il2cpp_domain_get_assemblies_t      fn_domain_get_assemblies = nullptr;
static il2cpp_assembly_get_image_t         fn_assembly_get_image = nullptr;
static il2cpp_image_get_class_count_t      fn_image_get_class_count = nullptr;
static il2cpp_image_get_class_t            fn_image_get_class = nullptr;
static il2cpp_class_from_name_t            fn_class_from_name = nullptr;
static il2cpp_class_get_name_t             fn_class_get_name = nullptr;
static il2cpp_class_get_methods_t          fn_class_get_methods = nullptr;
static il2cpp_class_get_method_from_name_t fn_class_get_method = nullptr;
static il2cpp_method_get_name_t            fn_method_get_name = nullptr;
static il2cpp_class_get_type_t             fn_class_get_type = nullptr;
static il2cpp_type_get_object_t            fn_type_get_object = nullptr;
static il2cpp_string_new_t                 fn_string_new = nullptr;
static il2cpp_resolve_icall_t              fn_resolve_icall = nullptr;

// Unity Engine Functions
typedef Il2CppArray* (*Object_FindObjectsOfType_t)(void* systemType);
typedef Il2CppArray* (*Renderer_GetMaterials_t)(void* renderer);
typedef void*        (*Renderer_GetMaterial_t)(void* renderer);
typedef void*        (*Shader_Find_t)(void* nameStr);
typedef void         (*Material_SetShader_t)(void* material, void* shader);
typedef void         (*Material_SetInt_t)(void* material, void* nameStr, int value);
typedef void         (*Material_SetColor_t)(void* material, void* nameStr, Color color);

static Object_FindObjectsOfType_t u_FindObjectsOfType = nullptr;
static Renderer_GetMaterial_t     u_GetMaterial       = nullptr;
static Shader_Find_t              u_Shader_Find       = nullptr;
static Material_SetShader_t       u_SetShader         = nullptr;
static Material_SetInt_t          u_SetInt            = nullptr;
static Material_SetColor_t        u_SetColor          = nullptr;

static bool g_Il2CppReady = false;

void* FindMethodPointer(const char* namespaze, const char* className, const char* methodName, int argsCount) {
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

void* FindClassTypeObject(const char* namespaze, const char* className) {
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

bool InitIl2CppEngine() {
    if (g_Il2CppReady) return true;

    // Look in both UnityFramework and main binary
    void* handle = dlopen("UnityFramework.framework/UnityFramework", RTLD_LAZY);
    if (!handle) handle = dlopen(NULL, RTLD_NOW);
    if (!handle) return false;

    fn_domain_get            = (il2cpp_domain_get_t)dlsym(handle, "il2cpp_domain_get");
    fn_domain_get_assemblies = (il2cpp_domain_get_assemblies_t)dlsym(handle, "il2cpp_domain_get_assemblies");
    fn_assembly_get_image    = (il2cpp_assembly_get_image_t)dlsym(handle, "il2cpp_assembly_get_image");
    fn_image_get_class_count = (il2cpp_image_get_class_count_t)dlsym(handle, "il2cpp_image_get_class_count");
    fn_image_get_class       = (il2cpp_image_get_class_t)dlsym(handle, "il2cpp_image_get_class");
    fn_class_from_name       = (il2cpp_class_from_name_t)dlsym(handle, "il2cpp_class_from_name");
    fn_class_get_name        = (il2cpp_class_get_name_t)dlsym(handle, "il2cpp_class_get_name");
    fn_class_get_methods     = (il2cpp_class_get_methods_t)dlsym(handle, "il2cpp_class_get_methods");
    fn_class_get_method      = (il2cpp_class_get_method_from_name_t)dlsym(handle, "il2cpp_class_get_method_from_name");
    fn_method_get_name       = (il2cpp_method_get_name_t)dlsym(handle, "il2cpp_method_get_name");
    fn_class_get_type        = (il2cpp_class_get_type_t)dlsym(handle, "il2cpp_class_get_type");
    fn_type_get_object       = (il2cpp_type_get_object_t)dlsym(handle, "il2cpp_type_get_object");
    fn_string_new            = (il2cpp_string_new_t)dlsym(handle, "il2cpp_string_new");
    fn_resolve_icall         = (il2cpp_resolve_icall_t)dlsym(handle, "il2cpp_resolve_icall");

    if (!fn_domain_get || !fn_domain_get_assemblies) return false;

    // Resolve Unity Engine methods via MethodInfo or icall
    u_FindObjectsOfType = (Object_FindObjectsOfType_t)FindMethodPointer("UnityEngine", "Object", "FindObjectsOfType", 1);
    u_GetMaterial       = (Renderer_GetMaterial_t)FindMethodPointer("UnityEngine", "Renderer", "get_material", 0);
    if (!u_GetMaterial && fn_resolve_icall) {
        u_GetMaterial = (Renderer_GetMaterial_t)fn_resolve_icall("UnityEngine.Renderer::GetMaterial()");
    }
    u_Shader_Find       = (Shader_Find_t)FindMethodPointer("UnityEngine", "Shader", "Find", 1);
    u_SetShader         = (Material_SetShader_t)FindMethodPointer("UnityEngine", "Material", "set_shader", 1);
    u_SetInt            = (Material_SetInt_t)FindMethodPointer("UnityEngine", "Material", "SetInt", 2);
    u_SetColor          = (Material_SetColor_t)FindMethodPointer("UnityEngine", "Material", "SetColor", 2);

    g_Il2CppReady = true;
    return true;
}

// ============================================================================
// 4. AUTOMATIC WEAPON & RECOIL SCANNER (NO HARDCODED OFFSETS NEEDED)
// ============================================================================
bool ContainsKeyword(const char* text, const char* keyword) {
    if (!text || !keyword) return false;
    return strcasestr(text, keyword) != nullptr;
}

void ScanAndPatchAllWeaponMethods() {
    if (!InitIl2CppEngine() || !fn_image_get_class_count || !fn_image_get_class || !fn_class_get_methods) return;

    void* domain = fn_domain_get();
    size_t asmCount = 0;
    void** assemblies = fn_domain_get_assemblies(domain, &asmCount);
    int patched = 0;

    for (size_t a = 0; a < asmCount; a++) {
        void* image = fn_assembly_get_image(assemblies[a]);
        if (!image) continue;

        size_t classCount = fn_image_get_class_count(image);
        for (size_t c = 0; c < classCount; c++) {
            void* klass = fn_image_get_class(image, c);
            if (!klass) continue;

            const char* className = fn_class_get_name ? fn_class_get_name(klass) : "";
            if (!className) continue;

            // Only scan game logic classes related to weapons, guns, camera shake, or aiming
            bool isWeaponOrCamClass =
                ContainsKeyword(className, "Weapon") ||
                ContainsKeyword(className, "Gun")    ||
                ContainsKeyword(className, "Fire")   ||
                ContainsKeyword(className, "Shoot")  ||
                ContainsKeyword(className, "Recoil") ||
                ContainsKeyword(className, "Spread") ||
                ContainsKeyword(className, "Bullet") ||
                ContainsKeyword(className, "Rifle")  ||
                ContainsKeyword(className, "Pistol") ||
                ContainsKeyword(className, "Sway")   ||
                ContainsKeyword(className, "Shake");

            if (!isWeaponOrCamClass) continue;

            void* iter = nullptr;
            while (void* method = fn_class_get_methods(klass, &iter)) {
                Il2CppMethodInfo* mInfo = (Il2CppMethodInfo*)method;
                if (!mInfo->methodPointer) continue;

                const char* mName = fn_method_get_name ? fn_method_get_name(method) : mInfo->name;
                if (!mName) continue;

                // 1. Float Getter Functions -> Patch to return 0.0f
                if ((g_State.zeroRecoil && (ContainsKeyword(mName, "GetRecoil") || ContainsKeyword(mName, "get_recoil") || ContainsKeyword(mName, "GetKick") || ContainsKeyword(mName, "GetSway"))) ||
                    (g_State.zeroSpread && (ContainsKeyword(mName, "GetSpread") || ContainsKeyword(mName, "get_spread") || ContainsKeyword(mName, "GetInaccuracy") || ContainsKeyword(mName, "GetScatter") || ContainsKeyword(mName, "GetBloom") || ContainsKeyword(mName, "GetDeviation")))) {
                    if (PatchMemory(mInfo->methodPointer, kPatchRetFloatZero, sizeof(kPatchRetFloatZero))) {
                        patched++;
                    }
                }
                // 2. Action/Update Functions -> Patch with RET (NOP)
                else if ((g_State.zeroRecoil && (ContainsKeyword(mName, "AddRecoil") || ContainsKeyword(mName, "ApplyRecoil") || ContainsKeyword(mName, "DoRecoil") || ContainsKeyword(mName, "UpdateRecoil") || ContainsKeyword(mName, "Kickback") || ContainsKeyword(mName, "ShakeCamera") || ContainsKeyword(mName, "CameraShake"))) ||
                         (g_State.zeroSpread && (ContainsKeyword(mName, "AddSpread") || ContainsKeyword(mName, "ApplySpread") || ContainsKeyword(mName, "UpdateSpread") || ContainsKeyword(mName, "CalculateSpread")))) {
                    if (PatchMemory(mInfo->methodPointer, kPatchRetVoid, sizeof(kPatchRetVoid))) {
                        patched++;
                    }
                }
            }
        }
    }
    g_State.patchedCount = patched;
}

// ============================================================================
// 5. ACTIVE CHAMS WALLHACK LOOP (RUNS ON MAIN THREAD VIA CADISPLAYLINK)
// ============================================================================
void ExecuteWallhackChamsPass() {
    if (!g_State.wallhackChams || !InitIl2CppEngine()) return;
    if (!u_FindObjectsOfType || !u_GetMaterial || !fn_string_new) return;

    static void* skinnedMeshTypeObj = nullptr;
    if (!skinnedMeshTypeObj) {
        skinnedMeshTypeObj = FindClassTypeObject("UnityEngine", "SkinnedMeshRenderer");
    }
    if (!skinnedMeshTypeObj) return;

    Il2CppArray* renderers = u_FindObjectsOfType(skinnedMeshTypeObj);
    if (!renderers || renderers->max_length == 0) return;

    static void* chamsShader = nullptr;
    if (!chamsShader && u_Shader_Find) {
        chamsShader = u_Shader_Find(fn_string_new("Hidden/Internal-Colored"));
    }

    void* strZTest  = fn_string_new("_ZTest");
    void* strZWrite = fn_string_new("_ZWrite");
    void* strCull   = fn_string_new("_Cull");
    void* strColor  = fn_string_new("_Color");
    Color neonRed   = { 1.0f, 0.05f, 0.20f, 1.0f };

    uintptr_t count = renderers->max_length;
    if (count > 128) count = 128; // Safety cap

    for (uintptr_t i = 0; i < count; i++) {
        void* renderer = renderers->vector[i];
        if (!renderer) continue;

        void* mat = u_GetMaterial(renderer);
        if (!mat) continue;

        if (chamsShader && u_SetShader) {
            u_SetShader(mat, chamsShader);
        }
        if (u_SetInt) {
            u_SetInt(mat, strZTest, 8);  // 8 = CompareFunction.Always (Through Walls!)
            u_SetInt(mat, strZWrite, 0);
            u_SetInt(mat, strCull, 0);
        }
        if (u_SetColor) {
            u_SetColor(mat, strColor, neonRed);
        }
    }
}

// ============================================================================
// 6. NATIVE iOS 15-18 UIWINDOWSCENE MOD MENU & CROSSHAIR OVERLAY
// ============================================================================
@interface CFModMenuController : UIViewController
@property (nonatomic, strong) UIButton* floatingButton;
@property (nonatomic, strong) UIView* menuPanel;
@property (nonatomic, strong) UILabel* statusLabel;
@property (nonatomic, strong) CAShapeLayer* espLayer;
@property (nonatomic, strong) CADisplayLink* displayLink;
@property (nonatomic, assign) int frameCounter;
@end

@implementation CFModMenuController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor clearColor];

    // 1. Crosshair & ESP Layer
    self.espLayer = [CAShapeLayer layer];
    self.espLayer.frame = [UIScreen mainScreen].bounds;
    self.espLayer.strokeColor = [UIColor colorWithRed:0.0 green:1.0 blue:0.45 alpha:0.95].CGColor;
    self.espLayer.fillColor = [UIColor clearColor].CGColor;
    self.espLayer.lineWidth = 1.8f;
    [self.view.layer addSublayer:self.espLayer];

    // 2. Draggable "CF" Floating Button
    self.floatingButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.floatingButton.frame = CGRectMake(45, 100, 54, 54);
    self.floatingButton.backgroundColor = [UIColor colorWithRed:0.10 green:0.06 blue:0.20 alpha:0.95];
    self.floatingButton.layer.cornerRadius = 27;
    self.floatingButton.layer.borderWidth = 2.2f;
    self.floatingButton.layer.borderColor = [UIColor colorWithRed:0.0 green:1.0 blue:0.55 alpha:1.0].CGColor;
    [self.floatingButton setTitle:@"CF" forState:UIControlStateNormal];
    self.floatingButton.titleLabel.font = [UIFont boldSystemFontOfSize:17];
    [self.floatingButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [self.floatingButton addTarget:self action:@selector(toggleMenu) forControlEvents:UIControlEventTouchUpInside];

    UIPanGestureRecognizer* pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handleDrag:)];
    [self.floatingButton addGestureRecognizer:pan];
    [self.view addSubview:self.floatingButton];

    // 3. Mod Menu Panel
    self.menuPanel = [[UIView alloc] initWithFrame:CGRectMake(70, 70, 280, 250)];
    self.menuPanel.backgroundColor = [UIColor colorWithRed:0.06 green:0.06 blue:0.10 alpha:0.96];
    self.menuPanel.layer.cornerRadius = 14;
    self.menuPanel.layer.borderWidth = 1.5f;
    self.menuPanel.layer.borderColor = [UIColor colorWithRed:0.0 green:0.90 blue:0.50 alpha:0.85].CGColor;
    self.menuPanel.hidden = YES;

    UILabel* title = [[UILabel alloc] initWithFrame:CGRectMake(0, 10, 280, 24)];
    title.text = @"COUNTER FLAME v2 // ENGINE";
    title.textColor = [UIColor colorWithRed:0.0 green:1.0 blue:0.55 alpha:1.0];
    title.font = [UIFont boldSystemFontOfSize:13];
    title.textAlignment = NSTextAlignmentCenter;
    [self.menuPanel addSubview:title];

    self.statusLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 32, 280, 18)];
    self.statusLabel.text = @"Taraniyor...";
    self.statusLabel.textColor = [UIColor lightGrayColor];
    self.statusLabel.font = [UIFont systemFontOfSize:10];
    self.statusLabel.textAlignment = NSTextAlignmentCenter;
    [self.menuPanel addSubview:self.statusLabel];

    [self addSwitchRow:@"Wallhack (Duvar Arkasi Chams)" y:58  tag:1 initial:g_State.wallhackChams];
    [self addSwitchRow:@"Sabit Nisan (Crosshair Overlay)" y:98  tag:2 initial:g_State.crosshairESP];
    [self addSwitchRow:@"Sifir Sekme (No Recoil)"         y:138 tag:3 initial:g_State.zeroRecoil];
    [self addSwitchRow:@"Mermi Dagilmama (No Spread)"     y:178 tag:4 initial:g_State.zeroSpread];

    UIButton* rescanBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    rescanBtn.frame = CGRectMake(20, 214, 240, 28);
    rescanBtn.backgroundColor = [UIColor colorWithRed:0.18 green:0.12 blue:0.35 alpha:1.0];
    rescanBtn.layer.cornerRadius = 6;
    [rescanBtn setTitle:@"Macta Yeniden Aktif Et / Tara" forState:UIControlStateNormal];
    [rescanBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    rescanBtn.titleLabel.font = [UIFont boldSystemFontOfSize:11];
    [rescanBtn addTarget:self action:@selector(forceRescan) forControlEvents:UIControlEventTouchUpInside];
    [self.menuPanel addSubview:rescanBtn];

    [self.view addSubview:self.menuPanel];

    self.displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(renderTick)];
    [self.displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
}

- (void)addSwitchRow:(NSString*)labelTitle y:(CGFloat)y tag:(NSInteger)tag initial:(BOOL)val {
    UILabel* lbl = [[UILabel alloc] initWithFrame:CGRectMake(14, y, 195, 30)];
    lbl.text = labelTitle;
    lbl.textColor = [UIColor whiteColor];
    lbl.font = [UIFont systemFontOfSize:12 weight:UIFontWeightMedium];
    [self.menuPanel addSubview:lbl];

    UISwitch* sw = [[UISwitch alloc] initWithFrame:CGRectMake(215, y, 50, 30)];
    sw.on = val;
    sw.tag = tag;
    sw.onTintColor = [UIColor colorWithRed:0.0 green:0.85 blue:0.45 alpha:1.0];
    [sw addTarget:self action:@selector(switchChanged:) forControlEvents:UIControlEventValueChanged];
    [self.menuPanel addSubview:sw];
}

- (void)forceRescan {
    ScanAndPatchAllWeaponMethods();
    ExecuteWallhackChamsPass();
    self.statusLabel.text = [NSString stringWithFormat:@"IL2CPP: %s | Yamalanan Fonksiyon: %d",
                             g_Il2CppReady ? "AKTIF" : "BEKLIYOR", g_State.patchedCount];
}

- (void)switchChanged:(UISwitch*)sender {
    switch (sender.tag) {
        case 1:
            g_State.wallhackChams = sender.isOn;
            if (sender.isOn) ExecuteWallhackChamsPass();
            break;
        case 2:
            g_State.crosshairESP = sender.isOn;
            break;
        case 3:
            g_State.zeroRecoil = sender.isOn;
            if (sender.isOn) ScanAndPatchAllWeaponMethods();
            break;
        case 4:
            g_State.zeroSpread = sender.isOn;
            if (sender.isOn) ScanAndPatchAllWeaponMethods();
            break;
    }
    [self forceRescan];
}

- (void)toggleMenu {
    self.menuPanel.hidden = !self.menuPanel.hidden;
    if (!self.menuPanel.hidden) {
        [self forceRescan];
    }
}

- (void)handleDrag:(UIPanGestureRecognizer*)gesture {
    CGPoint translation = [gesture translationInView:self.view];
    gesture.view.center = CGPointMake(gesture.view.center.x + translation.x, gesture.view.center.y + translation.y);
    [gesture setTranslation:CGPointZero inView:self.view];
}

- (void)renderTick {
    self.frameCounter++;

    // Every 90 frames (~1.5 seconds), re-apply Chams to newly spawned players in the match
    if (self.frameCounter % 90 == 0) {
        if (g_State.wallhackChams) {
            ExecuteWallhackChamsPass();
        }
        if (g_State.patchedCount == 0 && (g_State.zeroRecoil || g_State.zeroSpread)) {
            ScanAndPatchAllWeaponMethods();
        }
    }

    if (!g_State.crosshairESP) {
        self.espLayer.path = NULL;
        return;
    }

    CGRect bounds = self.view.bounds;
    self.espLayer.frame = bounds;
    CGFloat cx = bounds.size.width * 0.5f;
    CGFloat cy = bounds.size.height * 0.5f;

    UIBezierPath* path = [UIBezierPath bezierPath];
    [path moveToPoint:CGPointMake(cx - 10, cy)];
    [path addLineToPoint:CGPointMake(cx + 10, cy)];
    [path moveToPoint:CGPointMake(cx, cy - 10)];
    [path addLineToPoint:CGPointMake(cx, cy + 10)];
    [path addArcWithCenter:CGPointMake(cx, cy) radius:4.0f startAngle:0 endAngle:(CGFloat)(M_PI * 2.0) clockwise:YES];

    self.espLayer.path = path.CGPath;
}

@end

// Pass-through window so game touches work seamlessly
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
// 7. DYLIB ENTRY POINT
// ============================================================================
__attribute__((constructor))
static void InitializeCounterFlameDylib() {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        AttachOverlayWindow();
        InitIl2CppEngine();
        ScanAndPatchAllWeaponMethods();
        ExecuteWallhackChamsPass();
    });
}
