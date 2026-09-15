# Product makefile for Android 17 Trout as a Xen DomU on Raspberry Pi 5.
#
# Derived from aosp_xenvm_trout_arm64.mk with all Renesas/Imagination/OP-TEE
# specifics removed (R-Car Gen5 hardware is absent on RPi5). The Trout
# virtualization stack (VHAL over vsock, EVS, car-emulator audio, multi-
# display, auto-ethernet) is retained. Graphics uses mesa + drm_hwcomposer
# instead of the PowerVR DDK.

# TARGET_PREBUILT_KERNEL - environment variable which could contain path to the prebuilt kernel.
ifneq ($(TARGET_PREBUILT_KERNEL),)
   # Set TARGET_KERNEL_PATH variable which defines which kernel will be used in trout device.
   TARGET_KERNEL_PATH := $(TARGET_PREBUILT_KERNEL)

   TARGET_KERNEL_USE := 6.1
endif

PRODUCT_SYSTEM_EXT_PROPERTIES += \
   dalvik.vm.usejit=false \

# Configure single touch device
PRODUCT_COPY_FILES += \
    device/epam/aosp-xenvm-trout/conf/Vendor_0627_Product_0003.idc:$(TARGET_COPY_OUT_VENDOR)/usr/idc/Vendor_0627_Product_0003.idc

# Disable UWB HAL
PRODUCT_COPY_FILES += \
    device/generic/car/common/android.hardware.disable.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.uwb.xml \

PRODUCT_COPY_FILES += \
    device/epam/aosp-xenvm-trout/init/xenvm_trout.init.rc:$(TARGET_COPY_OUT_PRODUCT)/etc/init/xenvm_trout.init.rc \

UEVENTD_ODM_COPY_FILE = device/epam/aosp-xenvm-trout/init/ueventd.xenvm.rc

LOCAL_OEMLOCK_PRODUCT_PACKAGE := android.hardware.oemlock-service.example

# No ro.hardware.egl/vulkan=powervr: RPi5 has no PowerVR GPU. Use mesa
# (software/llvmpipe) EGL + drm_hwcomposer on virtio-gpu. The Imagination DDK
# is only pulled in by build/graphics.mk, which is skipped because
# TARGET_BOARD_PLATFORM (bcm2712) is not in its R-Car/Imagination filter.
PRODUCT_VENDOR_PROPERTIES += ro.hardware.egl=mesa

# To override VHAL, declare LOCAL_VHAL_PRODUCT_PACKAGE
# prior to device/google/trout/aosp_trout_arm64.mk include
LOCAL_VHAL_PRODUCT_PACKAGE = android.hardware.automotive.vehicle@2.0-default-service

PRODUCT_VENDOR_PROPERTIES += \
    ro.carwatchdog.client_healthcheck.interval=20 \
    ro.carwatchdog.vhal_healthcheck.interval=10 \

ENABLE_EVS_SERVICE := false
ENABLE_EVS_SAMPLE := false

# Enable Thread Network HAL with simulation RCP
PRODUCT_PACKAGES += \
    com.android.hardware.threadnetwork-simulation-rcp

TARGET_RECOVERY_FSTAB := device/epam/aosp-xenvm-trout/shared/config/fstab.trout_xenvm

PRODUCT_VENDOR_PROPERTIES += \
	persist.vendor.otsim.local_interface=eth1

# Testing tool for vhost-vsock
PRODUCT_PACKAGES += \
    lisot

# Hwcomposer (works with virtio-gpu via drm_hwcomposer)
PRODUCT_PACKAGES += com.android.hardware.graphics.composer.drm_hwcomposer

# Generic graphics HAL packages (AOSP, NOT Imagination)
PRODUCT_PACKAGES += \
    android.hardware.graphics.common@1.0-impl \
    android.hardware.graphics.mapper@2.0-impl \
    android.hardware.graphics.mapper@2.0-impl-2.1 \
    android.hardware.graphics.allocator@2.0-impl \
    android.hardware.renderscript@1.0-impl \
    libion \
    libdrm \
    libLLVM \

# Graphics allocator/mapper HIDL HALs
PRODUCT_PACKAGES += \
    android.hardware.graphics.allocator@2.0-impl \
    android.hardware.graphics.mapper@2.0-impl-2.1

# Graphics allocator AIDL V1 HAL
PRODUCT_PACKAGES += \
    android.hardware.graphics.allocator-V1-ndk.vendor

PRODUCT_PACKAGES += \
    android.hardware.graphics.allocator@2.0.vndk-sp \
    android.hardware.graphics.mapper@2.0.vndk-sp \
    android.hardware.graphics.mapper@2.1.vndk-sp \
    android.hardware.graphics.common@1.0.vndk-sp \
    android.hardware.atrace@1.0.vndk-sp \
    libhwbinder.vndk-sp \
    libbase.vndk-sp \
    libcutils.vndk-sp \
    libhardware.vndk-sp \
    libhidlbase.vndk-sp \
    libhidltransport.vndk-sp \
    libutils.vndk-sp \
    libc++.vndk-sp \
    libRS_internal.vndk-sp \
    libRSDriver.vndk-sp \
    libRSCpuRef.vndk-sp \
    libbcinfo.vndk-sp \
    libblas.vndk-sp \
    libft2.vndk-sp \
    libpng.vndk-sp \
    libcompiler_rt.vndk-sp \
    libbacktrace.vndk-sp \
    libunwind.vndk-sp \
    libunwindstack.vndk-sp \
    liblzma.vndk-sp \
    libion.vndk-sp \
    android.hardware.graphics.composer@2.1 \
    android.hardware.graphics.allocator-V2-ndk.vendor \
    libgralloctypes.vendor

PRODUCT_DEFAULT_PROPERTY_OVERRIDES += ro.surface_flinger.max_frame_buffer_acquired_buffers=3

# Dumpstate
PRODUCT_PACKAGES += \
    android.hardware.dumpstate@1.1 \
    android.hardware.dumpstate@1.1.vendor \
    android.hardware.dumpstate-V1-ndk.vendor

 # Testing tool for display
 PRODUCT_PACKAGES += \
    modetest \

# Display settings for multi-display support
PRODUCT_COPY_FILES += \
    device/epam/aosp-xenvm-trout/display_settings.xml:$(TARGET_COPY_OUT_VENDOR)/etc/display_settings.xml \

# Display layout for multi-display support
PRODUCT_COPY_FILES += \
    device/epam/aosp-xenvm-trout/display_layout_configuration.xml:$(TARGET_COPY_OUT_VENDOR)/etc/displayconfig/display_layout_configuration.xml \

# Display permissions for multi-display support
PRODUCT_COPY_FILES += \
    frameworks/native/data/etc/android.software.activities_on_secondary_displays.xml:system/etc/permissions/android.software.activities_on_secondary_displays.xml \

# CarService RRO overlay for multi-display support
PRODUCT_PACKAGES += CarServiceOverlayXenVm
# Default launcher package for secondary display for multi-display and multi-user support
PRODUCT_PACKAGES += com.android.car.carlauncher

# ---- Multi-display / Multi-user (UserPicker) configuration ----
# Enable visible background users on secondary displays.
PRODUCT_SYSTEM_DEFAULT_PROPERTIES += fw.visible_bg_users=true

DEVICE_PRODUCT_COMPATIBILITY_MATRIX_FILE += device/epam/aosp-xenvm-trout/compatibility_matrix.xml

# Enable auto ethernet setup and config scripts for eth1
# interface used for host-guest communication in xenvm
PRODUCT_PACKAGES += \
    auto_ethernet_setup_script_xenvm \
    auto_ethernet_config_script_xenvm

TARGET_NO_TELEPHONY := true

# EVS Camera HAL (virtual camera over vsock)
PRODUCT_PACKAGES += \
    android.hardware.automotive.evs-xt \
    evs_app-xt \
    evsmanagerd-xt \
    TroutEvsOverlay \

ENABLE_EVS_SAMPLE := true
ENABLE_EVS_SERVICE := true
ENABLE_REAR_VIEW_CAMERA_SAMPLE := true
ENABLE_CAREVSSERVICE_SAMPLE := true

# NOTE: build/graphics.mk (Imagination DDK) and optee/optee.mk (R-Car OP-TEE)
# are intentionally NOT inherited here.
$(call inherit-product, device/epam/aosp-xenvm-trout/aosp_xenvm_trout_common.mk)
$(call inherit-product, device/google/trout/aosp_trout_arm64.mk)

LOCAL_BT_PROPERTIES = \
 vendor.ser.bt-uart=/dev/hvc5 \

PRODUCT_NAME := aosp_xenvm_rpi5_arm64
PRODUCT_DEVICE := xenvm_rpi5_arm64
PRODUCT_MODEL := xenvm rpi5 arm64 trout
