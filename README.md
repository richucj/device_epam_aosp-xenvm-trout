# android_device_epam_xenvm-trout

Implementation of the xenvm_trout AOSP device.

## Targets

* `xenvm_trout_arm64` — R-Car Gen5 (x5h) Xen guest (requires Renesas /
  Imagination proprietary prebuilts from `proprietary.xml`).
* `xenvm_rpi5_arm64` — **Raspberry Pi 5 (bcm2712) Xen DomU**, RPi5-only, no
  proprietary prebuilts. See [`XEN_RPI5_BUILD.md`](XEN_RPI5_BUILD.md) for the
  build & wiring guide (manifest sync, Xen 6.18 guest kernel,
  `TARGET_PREBUILT_KERNEL`, guest DTB, DomU config).
