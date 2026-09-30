#pragma once

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/classes/rendering_device.hpp>
#include <godot_cpp/classes/rendering_server.hpp>
#include <godot_cpp/variant/rid.hpp>
#include <godot_cpp/variant/string.hpp>

#include <vulkan/vulkan.h>
#include <cstdint>

namespace godot {

class GpuVisionBridge : public RefCounted {
    GDCLASS(GpuVisionBridge, RefCounted)

    RenderingDevice *rd = nullptr;
    RenderingServer *rs = nullptr;
    VkDevice device = VK_NULL_HANDLE;
    VkPhysicalDevice physical_device = VK_NULL_HANDLE;
    VkImage images[2] = {VK_NULL_HANDLE, VK_NULL_HANDLE};
    VkDeviceMemory memories[2] = {VK_NULL_HANDLE, VK_NULL_HANDLE};
    int fds[2] = {-1, -1};
    uint64_t allocation_sizes[2] = {0, 0};
    RID sources[2];
    RID wrappers[2];
    int width = 0;
    int height = 0;
    bool ready = false;

    static int32_t find_memory_type(VkPhysicalDevice physical_device,
                                    uint32_t allowed_bits,
                                    VkMemoryPropertyFlags required_flags);
    bool create_image(int index);
    void release();

protected:
    static void _bind_methods();

public:
    ~GpuVisionBridge();
    bool initialize(const RID &left_viewport_texture,
                    const RID &right_viewport_texture,
                    int p_width, int p_height,
                    const String &socket_path, int agent_index = 0);
    bool capture(bool flush = true);
    bool is_ready() const { return ready; }
    int get_width() const { return width; }
    int get_height() const { return height; }
    void shutdown();
};

} // namespace godot
