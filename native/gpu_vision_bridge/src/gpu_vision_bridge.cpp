#include "gpu_vision_bridge.h"

#include <godot_cpp/classes/rd_texture_format.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/utility_functions.hpp>

#include <sys/socket.h>
#include <sys/un.h>
#include <unistd.h>
#include <cstring>

using namespace godot;

int32_t GpuVisionBridge::find_memory_type(VkPhysicalDevice p_device,
                                           uint32_t allowed_bits,
                                           VkMemoryPropertyFlags required_flags) {
    VkPhysicalDeviceMemoryProperties properties{};
    vkGetPhysicalDeviceMemoryProperties(p_device, &properties);
    for (uint32_t i = 0; i < properties.memoryTypeCount; ++i) {
        if ((allowed_bits & (1u << i)) &&
            (properties.memoryTypes[i].propertyFlags & required_flags) == required_flags) {
            return static_cast<int32_t>(i);
        }
    }
    return -1;
}

void GpuVisionBridge::_bind_methods() {
    ClassDB::bind_method(D_METHOD("initialize", "left_texture", "right_texture",
                                  "width", "height", "socket_path", "agent_index"),
                         &GpuVisionBridge::initialize, DEFVAL(0));
    ClassDB::bind_method(D_METHOD("capture", "flush"), &GpuVisionBridge::capture, DEFVAL(true));
    ClassDB::bind_method(D_METHOD("is_ready"), &GpuVisionBridge::is_ready);
    ClassDB::bind_method(D_METHOD("get_width"), &GpuVisionBridge::get_width);
    ClassDB::bind_method(D_METHOD("get_height"), &GpuVisionBridge::get_height);
    ClassDB::bind_method(D_METHOD("shutdown"), &GpuVisionBridge::shutdown);
}

GpuVisionBridge::~GpuVisionBridge() {
    release();
}

bool GpuVisionBridge::create_image(int index) {
    VkExternalMemoryImageCreateInfo external_info{};
    external_info.sType = VK_STRUCTURE_TYPE_EXTERNAL_MEMORY_IMAGE_CREATE_INFO;
    external_info.handleTypes = VK_EXTERNAL_MEMORY_HANDLE_TYPE_OPAQUE_FD_BIT;

    VkImageCreateInfo image_info{};
    image_info.sType = VK_STRUCTURE_TYPE_IMAGE_CREATE_INFO;
    image_info.pNext = &external_info;
    image_info.imageType = VK_IMAGE_TYPE_2D;
    image_info.format = VK_FORMAT_R8G8B8A8_UNORM;
    image_info.extent = {static_cast<uint32_t>(width), static_cast<uint32_t>(height), 1};
    image_info.mipLevels = 1;
    image_info.arrayLayers = 1;
    image_info.samples = VK_SAMPLE_COUNT_1_BIT;
    image_info.tiling = VK_IMAGE_TILING_OPTIMAL;
    image_info.usage = VK_IMAGE_USAGE_TRANSFER_DST_BIT |
                       VK_IMAGE_USAGE_TRANSFER_SRC_BIT |
                       VK_IMAGE_USAGE_SAMPLED_BIT;
    image_info.sharingMode = VK_SHARING_MODE_EXCLUSIVE;
    image_info.initialLayout = VK_IMAGE_LAYOUT_UNDEFINED;

    VkPhysicalDeviceExternalImageFormatInfo external_query{};
    external_query.sType = VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_EXTERNAL_IMAGE_FORMAT_INFO;
    external_query.handleType = VK_EXTERNAL_MEMORY_HANDLE_TYPE_OPAQUE_FD_BIT;
    VkPhysicalDeviceImageFormatInfo2 format_query{};
    format_query.sType = VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_IMAGE_FORMAT_INFO_2;
    format_query.pNext = &external_query;
    format_query.format = image_info.format;
    format_query.type = image_info.imageType;
    format_query.tiling = image_info.tiling;
    format_query.usage = image_info.usage;
    format_query.flags = image_info.flags;
    VkExternalImageFormatProperties external_properties{};
    external_properties.sType = VK_STRUCTURE_TYPE_EXTERNAL_IMAGE_FORMAT_PROPERTIES;
    VkImageFormatProperties2 format_properties{};
    format_properties.sType = VK_STRUCTURE_TYPE_IMAGE_FORMAT_PROPERTIES_2;
    format_properties.pNext = &external_properties;
    VkResult result = vkGetPhysicalDeviceImageFormatProperties2(
        physical_device, &format_query, &format_properties);
    if (result != VK_SUCCESS ||
        !(external_properties.externalMemoryProperties.externalMemoryFeatures &
          VK_EXTERNAL_MEMORY_FEATURE_EXPORTABLE_BIT)) {
        UtilityFunctions::push_error("OPAQUE_FD external image format is not exportable");
        return false;
    }

    result = vkCreateImage(device, &image_info, nullptr, &images[index]);
    if (result != VK_SUCCESS) return false;
    VkMemoryRequirements requirements{};
    vkGetImageMemoryRequirements(device, images[index], &requirements);
    int32_t memory_type = find_memory_type(
        physical_device, requirements.memoryTypeBits, VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT);
    if (memory_type < 0) return false;

    VkMemoryDedicatedAllocateInfo dedicated{};
    dedicated.sType = VK_STRUCTURE_TYPE_MEMORY_DEDICATED_ALLOCATE_INFO;
    dedicated.image = images[index];
    VkExportMemoryAllocateInfo export_info{};
    export_info.sType = VK_STRUCTURE_TYPE_EXPORT_MEMORY_ALLOCATE_INFO;
    export_info.pNext = &dedicated;
    export_info.handleTypes = VK_EXTERNAL_MEMORY_HANDLE_TYPE_OPAQUE_FD_BIT;
    VkMemoryAllocateInfo allocation{};
    allocation.sType = VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO;
    allocation.pNext = &export_info;
    allocation.allocationSize = requirements.size;
    allocation.memoryTypeIndex = static_cast<uint32_t>(memory_type);
    result = vkAllocateMemory(device, &allocation, nullptr, &memories[index]);
    if (result != VK_SUCCESS) return false;
    result = vkBindImageMemory(device, images[index], memories[index], 0);
    if (result != VK_SUCCESS) return false;

    uint32_t usage = RenderingDevice::TEXTURE_USAGE_SAMPLING_BIT |
                     RenderingDevice::TEXTURE_USAGE_CAN_COPY_TO_BIT |
                     RenderingDevice::TEXTURE_USAGE_CAN_COPY_FROM_BIT;
    wrappers[index] = rd->texture_create_from_extension(
        RenderingDevice::TEXTURE_TYPE_2D,
        RenderingDevice::DATA_FORMAT_R8G8B8A8_UNORM,
        RenderingDevice::TEXTURE_SAMPLES_1, usage,
        static_cast<uint64_t>(reinterpret_cast<uintptr_t>(images[index])),
        width, height, 1, 1, 1);
    if (!wrappers[index].is_valid()) return false;

    VkMemoryGetFdInfoKHR fd_info{};
    fd_info.sType = VK_STRUCTURE_TYPE_MEMORY_GET_FD_INFO_KHR;
    fd_info.memory = memories[index];
    fd_info.handleType = VK_EXTERNAL_MEMORY_HANDLE_TYPE_OPAQUE_FD_BIT;
    PFN_vkGetMemoryFdKHR get_memory_fd = reinterpret_cast<PFN_vkGetMemoryFdKHR>(
        vkGetDeviceProcAddr(device, "vkGetMemoryFdKHR"));
    if (!get_memory_fd || get_memory_fd(device, &fd_info, &fds[index]) != VK_SUCCESS) {
        return false;
    }
    allocation_sizes[index] = requirements.size;
    return true;
}

bool GpuVisionBridge::initialize(const RID &left_viewport_texture,
                                 const RID &right_viewport_texture,
                                 int p_width, int p_height,
                                 const String &socket_path, int agent_index) {
    if (ready || p_width <= 0 || p_height <= 0) return false;
    rs = RenderingServer::get_singleton();
    if (!rs) return false;
    rd = rs->get_rendering_device();
    if (!rd) return false;
    sources[0] = rs->texture_get_rd_texture(left_viewport_texture, false);
    sources[1] = rs->texture_get_rd_texture(right_viewport_texture, false);
    if (!sources[0].is_valid() || !sources[1].is_valid()) {
        UtilityFunctions::push_error("GpuVisionBridge source RD texture is invalid");
        return false;
    }
    for (int i = 0; i < 2; ++i) {
        Ref<RDTextureFormat> source_format = rd->texture_get_format(sources[i]);
        if (source_format.is_null() || source_format->get_width() != p_width ||
            source_format->get_height() != p_height ||
            source_format->get_format() != RenderingDevice::DATA_FORMAT_R8G8B8A8_UNORM) {
            UtilityFunctions::push_error("GpuVisionBridge requires matching RGBA8 eye textures; eye ", i,
                " format null=", source_format.is_null(),
                " size=", source_format.is_valid() ? source_format->get_width() : -1, "x",
                source_format.is_valid() ? source_format->get_height() : -1,
                " expected=", p_width, "x", p_height,
                " format=", source_format.is_valid() ? static_cast<int>(source_format->get_format()) : -1);
            return false;
        }
    }
    width = p_width;
    height = p_height;

    uint64_t device_raw = rd->get_driver_resource(
        RenderingDevice::DRIVER_RESOURCE_LOGICAL_DEVICE, RID(), 0);
    uint64_t physical_raw = rd->get_driver_resource(
        RenderingDevice::DRIVER_RESOURCE_PHYSICAL_DEVICE, RID(), 0);
    if (!device_raw || !physical_raw) return false;
    device = reinterpret_cast<VkDevice>(static_cast<uintptr_t>(device_raw));
    physical_device = reinterpret_cast<VkPhysicalDevice>(static_cast<uintptr_t>(physical_raw));

    if (!create_image(0) || !create_image(1)) {
        release();
        return false;
    }

    CharString path = socket_path.utf8();
    sockaddr_un address{};
    if (path.length() >= static_cast<int>(sizeof(address.sun_path))) {
        release();
        return false;
    }
    int sock = ::socket(AF_UNIX, SOCK_STREAM, 0);
    if (sock < 0) { release(); return false; }
    address.sun_family = AF_UNIX;
    std::memcpy(address.sun_path, path.get_data(), path.length() + 1);
    if (::connect(sock, reinterpret_cast<sockaddr *>(&address), sizeof(address)) != 0) {
        ::close(sock);
        release();
        return false;
    }

    String metadata = "{\"agent_index\":" + String::num_int64(agent_index) + ",\"magic\":\"SDAEA_GPU_V1\",\"eyes\":2,\"width\":" +
        String::num_int64(width) + ",\"height\":" + String::num_int64(height) +
        ",\"vk_format\":37,\"allocation_sizes\":[" +
        String::num_uint64(allocation_sizes[0]) + "," +
        String::num_uint64(allocation_sizes[1]) + "]}";
    CharString bytes = metadata.utf8();
    int transfer_fds[2] = {this->fds[0], this->fds[1]};
    char control[CMSG_SPACE(sizeof(transfer_fds))]{};
    iovec iov{const_cast<char *>(bytes.get_data()), static_cast<size_t>(bytes.length())};
    msghdr message{};
    message.msg_iov = &iov;
    message.msg_iovlen = 1;
    message.msg_control = control;
    message.msg_controllen = sizeof(control);
    cmsghdr *cmsg = CMSG_FIRSTHDR(&message);
    cmsg->cmsg_level = SOL_SOCKET;
    cmsg->cmsg_type = SCM_RIGHTS;
    cmsg->cmsg_len = CMSG_LEN(sizeof(transfer_fds));
    std::memcpy(CMSG_DATA(cmsg), transfer_fds, sizeof(transfer_fds));
    bool sent = ::sendmsg(sock, &message, 0) == bytes.length();
    ::close(sock);
    ::close(this->fds[0]);
    ::close(this->fds[1]);
    this->fds[0] = this->fds[1] = -1;
    ready = sent;
    if (!ready) release();
    return ready;
}

bool GpuVisionBridge::capture(bool flush) {
    if (!ready || !rd || !rs) {
        UtilityFunctions::push_error("GpuVisionBridge capture called before successful initialization");
        return false;
    }
    for (int i = 0; i < 2; ++i) {
        Error result = rd->texture_copy(sources[i], wrappers[i],
            Vector3(0, 0, 0), Vector3(0, 0, 0), Vector3(width, height, 1),
            0, 0, 0, 0);
        if (result != OK) {
            UtilityFunctions::push_error("GpuVisionBridge texture_copy failed for eye ", i,
                " with RenderingDevice error ", static_cast<int>(result));
            return false;
        }
    }
    // Main RenderingDevice commands are flushed by a draw on the rendering
    // thread; force_sync waits for that GPU work before Python reads the FDs.
    if (flush) {
        rs->force_draw(false);
        rs->force_sync();
    }
    return true;
}

void GpuVisionBridge::release() {
    ready = false;
    if (rd) {
        for (RID &wrapper : wrappers) {
            if (wrapper.is_valid()) rd->free_rid(wrapper);
            wrapper = RID();
        }
    }
    if (rs) rs->force_sync();
    if (device) {
        for (int i = 0; i < 2; ++i) {
            if (images[i]) vkDestroyImage(device, images[i], nullptr);
            if (memories[i]) vkFreeMemory(device, memories[i], nullptr);
            images[i] = VK_NULL_HANDLE;
            memories[i] = VK_NULL_HANDLE;
        }
    }
    for (int &fd : fds) {
        if (fd >= 0) ::close(fd);
        fd = -1;
    }
}

void GpuVisionBridge::shutdown() {
    release();
    rd = nullptr;
    rs = nullptr;
    device = VK_NULL_HANDLE;
    physical_device = VK_NULL_HANDLE;
}
