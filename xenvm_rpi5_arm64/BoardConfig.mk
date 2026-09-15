#
# BoardConfig for Android 17 Trout as a Xen DomU on Raspberry Pi 5.
#
# Adapted from xenvm_trout_arm64 (R-Car Gen5 / x5h) but with all Renesas /
# Imagination / OP-TEE specifics removed so the target:
#   * builds WITHOUT the proprietary prebuilts that fail `repo sync`, and
#   * runs as a virtualized guest (virtio-gpu, virtio-blk, vsock/vuart)
#     on bcm2712 under the Xen hypervisor.
#
# Key differences vs xenvm_trout_arm64:
#   - TARGET_BOARD_PLATFORM := bcm2712 (NOT in the r8a7795/6/g/x5h filter in
#     build/graphics.mk), so the entire Imagination DDK (pvrsrvkm.ko,
#     rgx.fw, libEGL_powervr, ...) is skipped automatically.
#   - No R-Car PCIe firmware, no disfwk/vivid module filtering.
#   - Graphics via mesa (software/llvmpipe) + drm_hwcomposer on virtio-gpu.
#

TARGET_USERDATAIMAGE_PARTITION_SIZE := 7516192768 # 7 GB

# Kernel + modules are supplied externally (the Xen 6.18 guest kernel).
ifneq ($(TARGET_PREBUILT_MODULES_DIR),)
    SYSTEM_DLKM_SRC := $(TARGET_PREBUILT_MODULES_DIR)
endif

include device/google/trout/trout_arm64/BoardConfig.mk

ifneq ($(TARGET_PREBUILT_MODULES_DIR),)
    KERNEL_MODULES_PATH := $(TARGET_PREBUILT_MODULES_DIR)
    # Load every module present in the prebuilt modules dir (virtio, xen, ...)
    BOARD_VENDOR_RAMDISK_KERNEL_MODULES := $(filter-out $(TARGET_PREBUILT_MODULES_DIR),$(shell find $(TARGET_PREBUILT_MODULES_DIR) -type f -name *.ko))
    BOARD_VENDOR_RAMDISK_KERNEL_MODULES_LOAD = $(BOARD_VENDOR_RAMDISK_KERNEL_MODULES)
    BOARD_VENDOR_KERNEL_MODULES := $(BOARD_VENDOR_RAMDISK_KERNEL_MODULES)
    BOARD_VENDOR_KERNEL_MODULES_LOAD := $(BOARD_VENDOR_RAMDISK_KERNEL_MODULES_LOAD)
endif

BOARD_DO_NOT_STRIP_VENDOR_RAMDISK_MODULES := true
BOARD_DO_NOT_STRIP_VENDOR_MODULES := true

BOARD_SYSTEMIMAGE_PARTITION_SIZE := 2147483648 # 2 GB

SYSTEM_EXT_PRIVATE_SEPOLICY_DIRS += device/epam/aosp-xenvm-trout/sepolicy/private

BOARD_BOOTCONFIG := androidboot.fstab_name=fstab
BOARD_BOOTCONFIG += androidboot.fstab_suffix=trout_xenvm
BOARD_BOOTCONFIG += androidboot.vendor.apex.com.android.hardware.keymint=com.android.hardware.keymint.rust_nonsecure
BOARD_BOOTCONFIG += androidboot.vendor.apex.com.android.hardware.gatekeeper=com.android.hardware.gatekeeper.nonsecure
BOARD_BOOTCONFIG += androidboot.vendor.vehiclehal.server.cid=2
BOARD_BOOTCONFIG += androidboot.vendor.vehiclehal.server.port=9210
BOARD_BOOTCONFIG += androidboot.vendor.vehiclehal.server.psf=/data/data/power.file
BOARD_BOOTCONFIG += androidboot.vendor.vehiclehal.server.pss=/data/data/power.socket
BOARD_BOOTCONFIG += androidboot.selinux=permissive
BOARD_BOOTCONFIG += androidboot.android_dt_dir=/proc/device-tree/firmware#1/android/
BOARD_BOOTCONFIG += kernel.vmw_vsock_virtio_transport_common.virtio_transport_max_vsock_pkt_buf_size=16384
BOARD_BOOTCONFIG += androidboot.load_modules_parallel=true
BOARD_BOOTCONFIG += androidboot.lcd_density=160
BOARD_BOOTCONFIG += androidboot.hardware.hwcomposer=xenvm_rpi5_arm64
BOARD_BOOTCONFIG += androidboot.hardware.hwcomposer.mode=client
BOARD_BOOTCONFIG += androidboot.hardware.hwcomposer.display_finder_mode=drm

# TODO (boot integration): must match how Xen presents the Android disk(s)
# to the guest so /dev/block/by-name/* resolves. For a virtio-blk backend this
# is typically "virtio" (or the xen vbd, e.g. "xvda"). Adjust to match the
# by-name links the guest actually sees. See fstab.trout_xenvm.
BOARD_BOOTCONFIG += androidboot.boot_devices=virtio

BOARD_BOOTCONFIG += androidboot.openthread_node_id=1

# Reuse trout androidboot properties
BOARD_BOOTCONFIG += androidboot.hardware=xenvm_rpi5_arm64
BOARD_BOOTCONFIG += androidboot.cf_devcfg=1

# Set GPU properties
BOARD_BOOTCONFIG += androidboot.cpuvulkan.version=0

# Add WiFi configuration for VirtWifi network
BOARD_BOOTCONFIG += androidboot.wifi_mac_prefix=5554

# Override trout cmdline
BOARD_KERNEL_CMDLINE = enforcing=0
BOARD_KERNEL_CMDLINE += mac80211_hwsim.radios=0
BOARD_KERNEL_CMDLINE += audit=1
BOARD_KERNEL_CMDLINE += panic=-1
BOARD_KERNEL_CMDLINE += 8250.nr_uarts=1

BOARD_VENDOR_SEPOLICY_DIRS += device/google/cuttlefish/shared/virgl/sepolicy

# Raspberry Pi 5 SoC. Not in the Imagination graphics.mk filter, so the whole
# PowerVR DDK (KM/UM, rgx.fw, libEGL_powervr, ...) is skipped.
override TARGET_BOARD_PLATFORM := bcm2712

PRODUCT_COPY_FILES := $(filter-out \
    device/google/trout/product_files/etc/automotive/evs/config_override.json:%, \
    $(PRODUCT_COPY_FILES))

PRODUCT_COPY_FILES := $(filter-out \
    device/google/trout/product_files/vendor/etc/automotive/evs/evs_configuration_override.xml:%, \
    $(PRODUCT_COPY_FILES))
