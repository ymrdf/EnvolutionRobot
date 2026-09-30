#include "gpu_vision_bridge.h"

#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/godot.hpp>

using namespace godot;

static void initialize_gpu_vision_bridge(ModuleInitializationLevel level) {
    if (level == MODULE_INITIALIZATION_LEVEL_SCENE) {
        GDREGISTER_CLASS(GpuVisionBridge);
    }
}

static void uninitialize_gpu_vision_bridge(ModuleInitializationLevel) {}

extern "C" {
GDExtensionBool GDE_EXPORT gpu_vision_bridge_init(
        GDExtensionInterfaceGetProcAddress get_proc_address,
        GDExtensionClassLibraryPtr library,
        GDExtensionInitialization *initialization) {
    GDExtensionBinding::InitObject init_obj(get_proc_address, library, initialization);
    init_obj.register_initializer(initialize_gpu_vision_bridge);
    init_obj.register_terminator(uninitialize_gpu_vision_bridge);
    init_obj.set_minimum_library_initialization_level(MODULE_INITIALIZATION_LEVEL_SCENE);
    return init_obj.init();
}
}
