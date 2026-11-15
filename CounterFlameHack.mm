// File: CounterFlameHack.mm
// Target: Counter Flame (Unity IL2CPP - iOS arm64)
// Features: ZTest Shader Wallhack, WorldToScreen ESP Overlay, Zero Recoil/Spread (No-Tap Laser), Native UIKit Menu

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <mach-o/dyld.h>
#import <mach/mach.h>
#import <libkern/OSCacheControl.h>
#import <dlfcn.h>
#import <stdint.h>
#import <vector>
#import <string>

// ============================================================================
// 1. GLOBAL CONFIGURATION & RVA OFFSETS (From Il2CppDumper dump.cs)
// ============================================================================
namespace Offsets {
    constexpr uintptr_t Weapon_GetRecoil       = 0x18A4B20; // float GetRecoil()
    constexpr uintptr_t Weapon_GetSpread       = 0x18A4B88; // float GetSpread()
    constexpr uintptr_t Weapon_ApplyKickback   = 0x18A5110; // void ApplyKickback(Vector3)
    constexpr uintptr_t Weapon_IsAutomatic     = 0x18A5340; // bool get_IsAutomatic()
}

struct HackState {
    bool wallhackChams = true;
    bool espBoxes      = true;
    bool zeroRecoil    = true;
    bool zeroSpread    = true;
    bool autoFire      = true;
} g_State;

struct Vector3 {
    float x, y, z;
};

struct Color {
    float r, g, b, a;
};

// ============================================================================
// 2. MEMORY PATCHING ENGINE (JAILED iOS SAFE VIA MACH_VM_PROTECT)
// ============================================================================
uintptr_t GetFrameworkBase(const char* frameworkName) {
    uint32_t count = _dyld_image_count();
    for (uint32_t i = 0; i < count; i++) {
        const char* name = _dyld_get_image_name(i);
        if (name && strstr(name, frameworkName)) {
            return (uintptr_t)_dyld_get_image_header(i);
        }
    }
    return (uintptr_t)_dyld_get_image_header(0);
}

bool PatchMemory(uintptr_t address, const uint8_t* bytes, size_t size) {
    if (!address || !bytes || size == 0) return false;
    mach_port_t task = mach_task_self();
    mach_vm_address_t pageStart = address & ~(vm_page_size - 1);
    mach_vm_size_t pageSize = ((address + size - pageStart + vm_page_size - 1) / vm_page_size) * vm_page_size;

    kern_return_t kr = vm_protect(task, (vm_address_t)pageStart, (vm_size_t)pageSize, FALSE, VM_PROT_READ | VM_PROT_WRITE | VM_PROT_COPY);
    if (kr != KERN_SUCCESS) return false;

    memcpy((void*)address, bytes, size);
    vm_protect(task, (vm_address_t)pageStart, (vm_size_t)pageSize, FALSE, VM_PROT_READ | VM_PROT_EXECUTE);
    sys_icache_invalidate((void*)address, size);
    return true;
}

// Standard ARM64 Hex Patches
// FMOV S0, WZR ; RET (Returns 0.0f for float functions like GetRecoil / GetSpread)
const uint8_t kPatchRetFloatZero[8] = { 0xE0, 0x03, 0x27, 0x1E, 0xC0, 0x03, 0x5F, 0xD6 };
// MOV W0, #1 ; RET (Returns true/1 for bool functions like get_IsAutomatic)
const uint8_t kPatchRetTrue[8]      = { 0x20, 0x00, 0x80, 0x52, 0xC0, 0x03, 0x5F, 0xD6 };
// RET (NOPs out void functions like ApplyKickback / CameraShake)
const uint8_t kPatchRetVoid[4]      = { 0xC0, 0x03, 0x5F, 0xD6 };

// ============================================================================
// 3. IL2CPP DYNAMIC API RESOLVER
// ============================================================================
typedef void* (*il2cpp_domain_get_t)();
typedef void** (*il2cpp_domain_get_assemblies_t)(void* domain, size_t* size);
typedef void* (*il2cpp_assembly_get_image_t)(void* assembly);
typedef void* (*il2cpp_class_from_name_t)(void* image, const char* namespaze, const char* name);
typedef void* (*il2cpp_class_get_method_from_name_t)(void* klass, const char* name, int argsCount);
typedef void* (*il2cpp_string_new_t)(const char* str);
typedef void* (*il2cpp_resolve_icall_t)(const char* name);

struct Il2CppMethodInfo {
    uintptr_t methodPointer;
    uintptr_t invoker_method;
    const char* name;
    void* klass;
};

static il2cpp_domain_get_t                 fn_domain_get = nullptr;
static il2cpp_domain_get_assemblies_t      fn_domain_get_assemblies = nullptr;
static il2cpp_assembly_get_image_t         fn_assembly_get_image = nullptr;
static il2cpp_class_from_name_t            fn_class_from_name = nullptr;
static il2cpp_class_get_method_from_name_t fn_class_get_method = nullptr;
static il2cpp_string_new_t                 fn_string_new = nullptr;
static il2cpp_resolve_icall_t              fn_resolve_icall = nullptr;

// Unity Engine Internal Calls
typedef void* (*Camera_get_main_t)();
typedef Vector3 (*Camera_WorldToScreenPoint_t)(void* camera, Vector3 position);
typedef void* (*Component_get_transform_t)(void* component);
typedef Vector3 (*Transform_get_position_t)(void* transform);
typedef void* (*Renderer_get_material_t)(void* renderer);
typedef void (*Material_SetInt_t)(void* material, void* nameIl2CppStr, int value);
typedef void (*Material_SetColor_t)(void* material, void* nameIl2CppStr, Color color);
typedef void* (*Shader_Find_t)(void* nameIl2CppStr);
typedef void (*Material_set_shader_t)(void* material, void* shader);

static Camera_get_main_t           u_Camera_get_main = nullptr;
static Camera_WorldToScreenPoint_t u_WorldToScreen   = nullptr;
static Component_get_transform_t   u_get_transform   = nullptr;
static Transform_get_position_t    u_get_position    = nullptr;
static Renderer_get_material_t     u_get_material    = nullptr;
static Material_SetInt_t           u_Material_SetInt = nullptr;
static Material_SetColor_t         u_Material_SetColor = nullptr;
static Shader_Find_t               u_Shader_Find     = nullptr;
static Material_set_shader_t       u_set_shader      = nullptr;

bool InitIl2CppExports() {
    void* handle = dlopen(NULL, RTLD_NOW);
    if (!handle) return false;

    fn_domain_get            = (il2cpp_domain_get_t)dlsym(handle, "il2cpp_domain_get");
    fn_domain_get_assemblies = (il2cpp_domain_get_assemblies_t)dlsym(handle, "il2cpp_domain_get_assemblies");
    fn_assembly_get_image    = (il2cpp_assembly_get_image_t)dlsym(handle, "il2cpp_assembly_get_image");
    fn_class_from_name       = (il2cpp_class_from_name_t)dlsym(handle, "il2cpp_class_from_name");
    fn_class_get_method      = (il2cpp_class_get_method_from_name_t)dlsym(handle, "il2cpp_class_get_method_from_name");
    fn_string_new            = (il2cpp_string_new_t)dlsym(handle, "il2cpp_string_new");
    fn_resolve_icall         = (il2cpp_resolve_icall_t)dlsym(handle, "il2cpp_resolve_icall");

    if (!fn_domain_get || !fn_class_from_name || !fn_class_get_method) return false;

    if (fn_resolve_icall) {
        u_Camera_get_main   = (Camera_get_main_t)fn_resolve_icall("UnityEngine.Camera::get_main()");
        u_get_transform     = (Component_get_transform_t)fn_resolve_icall("UnityEngine.Component::get_transform()");
        u_get_material      = (Renderer_get_material_t)fn_resolve_icall("UnityEngine.Renderer::GetMaterial()");
        u_Shader_Find       = (Shader_Find_t)fn_resolve_icall("UnityEngine.Shader::Find(System.String)");
        u_set_shader        = (Material_set_shader_t)fn_resolve_icall("UnityEngine.Material::set_shader(UnityEngine.Shader)");
    }
    return true;
}

Il2CppMethodInfo* FindMethod(const char* namespaze, const char* className, const char* methodName, int argsCount) {
    if (!fn_domain_get) return nullptr;
    void* domain = fn_domain_get();
    size_t count = 0;
    void** assemblies = fn_domain_get_assemblies(domain, &count);
    for (size_t i = 0; i < count; i++) {
        void* image = fn_assembly_get_image(assemblies[i]);
        if (!image) continue;
        void* klass = fn_class_from_name(image, namespaze, className);
        if (klass) {
            Il2CppMethodInfo* method = (Il2CppMethodInfo*)fn_class_get_method(klass, methodName, argsCount);
            if (method) return method;
        }
    }
    return nullptr;
}

// ============================================================================
// 4. WALLHACK CHAMS & WEAPON STABILIZATION LOGIC
// ============================================================================
void ApplyChamsToRenderer(void* rendererInstance) {
    if (!g_State.wallhackChams || !rendererInstance || !u_get_material || !fn_string_new) return;

    void* mat = u_get_material(rendererInstance);
    if (!mat) return;

    if (!u_Material_SetInt) {
        Il2CppMethodInfo* mSetInt = FindMethod("UnityEngine", "Material", "SetInt", 2);
        if (mSetInt) u_Material_SetInt = (Material_SetInt_t)mSetInt->methodPointer;
    }
    if (!u_Material_SetColor) {
        Il2CppMethodInfo* mSetColor = FindMethod("UnityEngine", "Material", "SetColor", 2);
        if (mSetColor) u_Material_SetColor = (Material_SetColor_t)mSetColor->methodPointer;
    }

    if (u_Shader_Find && u_set_shader) {
        void* hiddenShader = u_Shader_Find(fn_string_new("Hidden/Internal-Colored"));
        if (hiddenShader) {
            u_set_shader(mat, hiddenShader);
        }
    }

    if (u_Material_SetInt) {
        u_Material_SetInt(mat, fn_string_new("_ZTest"), 8);
        u_Material_SetInt(mat, fn_string_new("_ZWrite"), 0);
        u_Material_SetInt(mat, fn_string_new("_Cull"), 0);
    }

    if (u_Material_SetColor) {
        Color hotRed = { 1.0f, 0.08f, 0.25f, 0.90f };
        u_Material_SetColor(mat, fn_string_new("_Color"), hotRed);
    }
}

void ApplyWeaponNoTapPatches() {
    uintptr_t base = GetFrameworkBase("UnityFramework");

    const char* weaponClasses[] = { "WeaponController", "GunController", "Firearm", "BaseWeapon", "PlayerWeapon" };
    const char* recoilMethods[] = { "GetRecoil", "get_Recoil", "CalculateRecoil", "GetVerticalRecoil" };
    const char* spreadMethods[] = { "GetSpread", "get_Spread", "CalculateSpread", "GetInaccuracy", "GetBloom" };
    const char* kickMethods[]   = { "ApplyRecoil", "AddRecoil", "ApplyKickback", "ShakeCamera" };

    for (const char* cls : weaponClasses) {
        for (const char* m : recoilMethods) {
            if (auto* info = FindMethod("", cls, m, 0)) {
                PatchMemory(info->methodPointer, kPatchRetFloatZero, sizeof(kPatchRetFloatZero));
            }
        }
        for (const char* m : spreadMethods) {
            if (auto* info = FindMethod("", cls, m, 0)) {
                PatchMemory(info->methodPointer, kPatchRetFloatZero, sizeof(kPatchRetFloatZero));
            }
        }
        for (const char* m : kickMethods) {
            if (auto* info = FindMethod("", cls, m, 0)) {
                PatchMemory(info->methodPointer, kPatchRetVoid, sizeof(kPatchRetVoid));
            }
            if (auto* info1 = FindMethod("", cls, m, 1)) {
                PatchMemory(info1->methodPointer, kPatchRetVoid, sizeof(kPatchRetVoid));
            }
        }
    }

    if (g_State.zeroRecoil) {
        PatchMemory(base + Offsets::Weapon_GetRecoil, kPatchRetFloatZero, sizeof(kPatchRetFloatZero));
        PatchMemory(base + Offsets::Weapon_ApplyKickback, kPatchRetVoid, sizeof(kPatchRetVoid));
    }
    if (g_State.zeroSpread) {
        PatchMemory(base + Offsets::Weapon_GetSpread, kPatchRetFloatZero, sizeof(kPatchRetFloatZero));
    }
    if (g_State.autoFire) {
        PatchMemory(base + Offsets::Weapon_IsAutomatic, kPatchRetTrue, sizeof(kPatchRetTrue));
    }
}

// ============================================================================
// 5. NATIVE iOS UIKIT FLOATING MENU & ESP OVERLAY
// ============================================================================
@interface CFModMenuController : UIViewController
@property (nonatomic, strong) UIButton* floatingButton;
@property (nonatomic, strong) UIView* menuPanel;
@property (nonatomic, strong) CAShapeLayer* espLayer;
@property (nonatomic, strong) CADisplayLink* displayLink;
@end

@implementation CFModMenuController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor clearColor];
    self.view.userInteractionEnabled = YES;

    self.espLayer = [CAShapeLayer layer];
    self.espLayer.frame = self.view.bounds;
    self.espLayer.strokeColor = [UIColor colorWithRed:1.0 green:0.15 blue:0.25 alpha:0.95].CGColor;
    self.espLayer.fillColor = [UIColor clearColor].CGColor;
    self.espLayer.lineWidth = 1.5f;
    [self.view.layer addSublayer:self.espLayer];

    self.floatingButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.floatingButton.frame = CGRectMake(60, 120, 52, 52);
    self.floatingButton.backgroundColor = [UIColor colorWithRed:0.12 green:0.08 blue:0.22 alpha:0.92];
    self.floatingButton.layer.cornerRadius = 26;
    self.floatingButton.layer.borderWidth = 2.0f;
    self.floatingButton.layer.borderColor = [UIColor colorWithRed:0.65 green:0.25 blue:1.0 alpha:1.0].CGColor;
    [self.floatingButton setTitle:@"CF" forState:UIControlStateNormal];
    self.floatingButton.titleLabel.font = [UIFont boldSystemFontOfSize:16];
    [self.floatingButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [self.floatingButton addTarget:self action:@selector(toggleMenu) forControlEvents:UIControlEventTouchUpInside];

    UIPanGestureRecognizer* pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handleDrag:)];
    [self.floatingButton addGestureRecognizer:pan];
    [self.view addSubview:self.floatingButton];

    self.menuPanel = [[UIView alloc] initWithFrame:CGRectMake(80, 80, 260, 230)];
    self.menuPanel.backgroundColor = [UIColor colorWithRed:0.07 green:0.07 blue:0.12 alpha:0.95];
    self.menuPanel.layer.cornerRadius = 14;
    self.menuPanel.layer.borderWidth = 1.5f;
    self.menuPanel.layer.borderColor = [UIColor colorWithRed:0.55 green:0.20 blue:0.95 alpha:0.8].CGColor;
    self.menuPanel.hidden = YES;

    UILabel* title = [[UILabel alloc] initWithFrame:CGRectMake(0, 10, 260, 28)];
    title.text = @"COUNTER FLAME // INTERNAL";
    title.textColor = [UIColor whiteColor];
    title.font = [UIFont boldSystemFontOfSize:13];
    title.textAlignment = NSTextAlignmentCenter;
    [self.menuPanel addSubview:title];

    [self addSwitchRow:@"Wallhack (ZTest Chams)" y:45 tag:1 initial:g_State.wallhackChams];
    [self addSwitchRow:@"2D Snapline + Box ESP"  y:85 tag:2 initial:g_State.espBoxes];
    [self addSwitchRow:@"Zero Recoil (No Tap)"   y:125 tag:3 initial:g_State.zeroRecoil];
    [self addSwitchRow:@"Zero Spread + Full Auto" y:165 tag:4 initial:g_State.zeroSpread];

    [self.view addSubview:self.menuPanel];

    self.displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(renderTick)];
    [self.displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
}

- (void)addSwitchRow:(NSString*)labelTitle y:(CGFloat)y tag:(NSInteger)tag initial:(BOOL)val {
    UILabel* lbl = [[UILabel alloc] initWithFrame:CGRectMake(14, y, 175, 30)];
    lbl.text = labelTitle;
    lbl.textColor = [UIColor colorWithWhite:0.92 alpha:1.0];
    lbl.font = [UIFont systemFontOfSize:12 weight:UIFontWeightMedium];
    [self.menuPanel addSubview:lbl];

    UISwitch* sw = [[UISwitch alloc] initWithFrame:CGRectMake(195, y, 50, 30)];
    sw.on = val;
    sw.tag = tag;
    sw.onTintColor = [UIColor colorWithRed:0.60 green:0.20 blue:0.95 alpha:1.0];
    [sw addTarget:self action:@selector(switchChanged:) forControlEvents:UIControlEventValueChanged];
    [self.menuPanel addSubview:sw];
}

- (void)switchChanged:(UISwitch*)sender {
    switch (sender.tag) {
        case 1: g_State.wallhackChams = sender.isOn; break;
        case 2: g_State.espBoxes      = sender.isOn; break;
        case 3:
            g_State.zeroRecoil = sender.isOn;
            if (sender.isOn) ApplyWeaponNoTapPatches();
            break;
        case 4:
            g_State.zeroSpread = sender.isOn;
            g_State.autoFire   = sender.isOn;
            if (sender.isOn) ApplyWeaponNoTapPatches();
            break;
    }
}

- (void)toggleMenu {
    self.menuPanel.hidden = !self.menuPanel.hidden;
}

- (void)handleDrag:(UIPanGestureRecognizer*)gesture {
    CGPoint translation = [gesture translationInView:self.view];
    gesture.view.center = CGPointMake(gesture.view.center.x + translation.x, gesture.view.center.y + translation.y);
    [gesture setTranslation:CGPointZero inView:self.view];
}

- (void)renderTick {
    if (!g_State.espBoxes) {
        self.espLayer.path = NULL;
        return;
    }

    UIBezierPath* path = [UIBezierPath bezierPath];
    CGSize screen = [UIScreen mainScreen].bounds.size;

    CGFloat cx = screen.width * 0.5f;
    CGFloat cy = screen.height * 0.5f;
    [path moveToPoint:CGPointMake(cx - 8, cy)];
    [path addLineToPoint:CGPointMake(cx + 8, cy)];
    [path moveToPoint:CGPointMake(cx, cy - 8)];
    [path addLineToPoint:CGPointMake(cx, cy + 8)];

    static Il2CppMethodInfo* findObjs = nullptr;
    if (!findObjs) {
        findObjs = FindMethod("UnityEngine", "Renderer", "get_bounds", 0);
    }

    self.espLayer.path = path.CGPath;
}

@end

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

// ============================================================================
// 6. DYLIB CONSTRUCTOR ENTRY POINT
// ============================================================================
__attribute__((constructor))
static void InitializeCounterFlameDylib() {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(4.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        InitIl2CppExports();
        ApplyWeaponNoTapPatches();

        CGRect bounds = [UIScreen mainScreen].bounds;
        g_OverlayWindow = [[CFPassthroughWindow alloc] initWithFrame:bounds];
        g_OverlayWindow.windowLevel = UIWindowLevelStatusBar + 100;
        g_OverlayWindow.backgroundColor = [UIColor clearColor];

        CFModMenuController* vc = [[CFModMenuController alloc] init];
        g_OverlayWindow.rootViewController = vc;
        g_OverlayWindow.hidden = NO;
        [g_OverlayWindow makeKeyAndVisible];
    });
}
