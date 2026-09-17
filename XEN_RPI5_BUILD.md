# Build & Wiring Guide — Android 17 Trout as a Xen DomU on Raspberry Pi 5

This guide describes how to build and boot **Android 17 (Trout) as a Xen guest
(DomU)** on the **Raspberry Pi 5 (bcm2712)**. It complements the target
`aosp_xenvm_rpi5_arm64` added under `device/epam/aosp-xenvm-trout`.

> Scope: this guide is for **RPi5 only**. The original `xenvm_trout_arm64`
> target is for R-Car Gen5 (x5h) and is **not** used here. The Renesas /
> Imagination proprietary prebuilts that fail `repo sync` are intentionally
> excluded (see the `rj/xenBringup` manifest branch).

---

## 0. Architecture overview

```
            +-----------------------------------------------+
            |                Xen hypervisor (EL2)          |
            |   built separately via meta-xt-prod-devel-   |
            |   rpi5 (Yocto) — NOT part of this AOSP tree  |
            +---------------------------+-------------------+
            |   Dom0 (Linux, safety/   |   DomU (Android   |
            |   control plane)         |   17 Trout)       |
            |   - Xen tooling / xl     |   - This AOSP     |
            |   - VHAL vsock server    |     build         |
            |     (cid=2 port=9210)    |   - Xen 6.18      |
            |   - safety-critical      |     guest kernel  |
            +--------------------------+-------------------+
                       virtio-blk / virtio-gpu / vsock / vuart
```

* **Xen hypervisor + Dom0**: provided by your separate Xen build
  (`~/Documents/rpi5/meta-xt-prod-devel-rpi5`, based on
  xen-troops/meta-xt-prod-devel-rpi5 issue #71 — adapted to Android 17).
* **Xen guest kernel**: `kernel/xen-virtual-device` @
  `common-android17-6.18-xenvm-trout-ih-main` is the Android **`virtual_device`
  kernel overlay** — defconfig fragments (`xenvm.aarch64.fragment`,
  `virtual_device_core.fragment`, …) enabling `CONFIG_XEN=y`, virtio-blk/
  console/vsock, `CONFIG_DRM_VIRTIO_GPU`, plus a `dma_buf_cma_heap` module. It
  is **not** the kernel source. The actual `Image` is produced by layering
  these fragments on a base GKI kernel (`kernel/common` @ 6.18) via Android's
  `build/kernel`, **or** by your separate Xen/Yocto build
  (`meta-xt-prod-devel-rpi5`), which already builds the guest kernel. You then
  point `TARGET_PREBUILT_KERNEL` at that `Image`.
* **Android userspace**: this AOSP tree, target `aosp_xenvm_rpi5_arm64`.

The bare-metal RPi5 kernel (`device/brcm/rpi5-kernel`) is **not** used for the
guest; it is only relevant for a bare-metal boot. For Xen we use the dedicated
guest kernel above.

---

## 1. Manifest / `repo sync`

Use the `rj/xenBringup` branch of the manifest repo. It:

* includes `aosp.xml`, `aosp-device-xenvm-trout.xml`, and a new
  `aosp-kernel-xen.xml` (adds `kernel/xen-virtual-device`);
* **omits** `proprietary.xml` (the failing Renesas/Imagination prebuilts);
* points `aosp-device-xenvm-trout.xml` at `device/epam/aosp-xenvm-trout`
  revision `rj/xenBringup`.

The `rj/xenBringup` manifest **already excludes** `proprietary.xml` (the R-Car /
Imagination prebuilts), so `repo sync` works without the partnergitlab
credentials and **no local `remove-project` overlay is needed** — adding one
would actually break sync, because those projects are no longer in the merged
manifest.

> If you instead `repo init` against the upstream `android-17-xenvm-trout-ih-main`
> manifest, the R-Car prebuilts *are* included and `repo sync` fails on their
> auth — that is precisely why this `rj/xenBringup` branch exists.

Then sync:

```bash
repo sync -j$(nproc)
```

> **Note:** the manifest pins `device/epam/aosp-xenvm-trout` to a fixed
> revision via `aosp-device-xenvm-trout.xml`, so after every `repo sync` your
> working tree is reset to that commit. To keep working on the
> `rj/xenBringup` branch of the device repo, re-checkout after sync:
>
> ```bash
> git -C device/epam/aosp-xenvm-trout checkout rj/xenBringup
> ```

---

## 2. The guest kernel — what `kernel/xen-virtual-device` actually is

`kernel/xen-virtual-device` (branch `common-android17-6.18-xenvm-trout-ih-main`)
is **not** the Linux kernel source. It is the Android **`virtual_device` kernel
overlay**: defconfig fragments (`virtual_device.fragment`,
`virtual_device_core.fragment`, `xenvm.aarch64.fragment`, …) that enable Xen PV
front-ends (`CONFIG_XEN=y`, gntdev, grant-alloc), virtio-blk/console/vsock/pci,
`CONFIG_DRM_VIRTIO_GPU`, and a small `dma_buf_cma_heap` module. The actual
`Image` is produced by **layering these fragments on a base GKI kernel**.

There are two ways to get the guest `Image` + modules + bcm2712 guest DTB:

**Option A — built by your separate Xen/Yocto build (recommended for the POC).**
Your `meta-xt-prod-devel-rpi5` tree already builds the Xen guest kernel (it
consumes these exact fragments). Take the `Image` it produces, the bcm2712
**guest** DTB (e.g. `bcm2712-rpi-5-xen.dtb` shipped by that tree), and the
built `*.ko`, and point `TARGET_PREBUILT_KERNEL` / `TARGET_PREBUILT_MODULES_DIR`
at them (Section 3). No kernel build happens in this AOSP tree.

**Option B — build in this AOSP tree.** This needs the base GKI kernel source
and Android's kernel build tooling, which are **not** in the `rj/xenBringup`
manifest yet:

* add `kernel/common` @ the matching `android17-6.18` branch and `build/kernel`
  to the manifest,
* then build the `virtual_device` (xenvm) target, e.g.:

```bash
# from this AOSP root, using build/kernel (adjust target name to your version)
tools/bazel run //common:kernel_xenvm_dist -- --arch=arm64
# or the legacy path:
cd build/kernel && ./build.sh --target=xenvm --arch=arm64
```

(The `xenvm.aarch64.fragment` is what selects the Xen guest config.)

Required artifacts (from either option):

| Artifact | Used for |
|----------|----------|
| `Image` (arm64) | `TARGET_PREBUILT_KERNEL` |
| bcm2712 guest DTB (`bcm2712-rpi-5-xen.dtb`) | packaged into boot/vendor_boot or passed by Xen |
| `lib/modules/<ver>/` (the `*.ko`) | `TARGET_PREBUILT_MODULES_DIR` |

The Xen/virtio options above (`CONFIG_XEN_*`, `CONFIG_VIRTIO_*`,
`CONFIG_DRM_VIRTIO_GPU`, `CONFIG_VSOCK`, virtio block/net front-ends) come from
the `xenvm.aarch64.fragment` / `virtual_device_core.fragment` in this overlay.

---

## 3. Build Android 17 with the prebuilt guest kernel

Set the two prebuilt env vars so the build uses your Xen guest kernel instead
of any in-tree kernel. `xenvm_rpi5_arm64/BoardConfig.mk` already wires
`TARGET_PREBUILT_MODULES_DIR` into `SYSTEM_DLKM_SRC`,
`BOARD_VENDOR_RAMDISK_KERNEL_MODULES`, and `BOARD_VENDOR_KERNEL_MODULES`, and
loads every `*.ko` found in that dir.

```bash
cd <aosp-root>
source build/envsetup.sh
export TARGET_PREBUILT_KERNEL=/path/to/xen-guest/Image      # from Option A or B above
export TARGET_PREBUILT_MODULES_DIR=/path/to/xen-guest/lib/modules/$(ls /path/to/xen-guest/lib/modules)

lunch aosp_xenvm_rpi5_arm64-trunk_staging-userdebug
make -j$(nproc)
```

What `xenvm_rpi5_arm64` sets for you (see
[`xenvm_rpi5_arm64/BoardConfig.mk`](xenvm_rpi5_arm64/BoardConfig.mk)):

* `TARGET_BOARD_PLATFORM := bcm2712` (overrides the `vsoc_arm64` default from
  trout) — this also means the Imagination PowerVR DDK in `build/graphics.mk`
  is **skipped** (bcm2712 is not in the `r8a7795/6/g/x5h` filter), so graphics
  falls back to mesa + `drm_hwcomposer` on virtio-gpu.
* `TARGET_CPU_VARIANT := cortex-a76` (correct for RPi5; the trout/cuttlefish
  default of `cortex-a53` is overridden here).
* `BOARD_BOOTCONFIG` / `BOARD_KERNEL_CMDLINE` tuned for the guest (vsock VHAL
  server `cid=2 port=9210`, `enforcing=0`, `8250.nr_uarts=1`, etc.).

The product makefile [`aosp_xenvm_rpi5_arm64.mk`](aosp_xenvm_rpi5_arm64.mk)
sets `ro.hardware.egl=mesa`, inherits `aosp_xenvm_trout_common.mk` +
`aosp_trout_arm64.mk`, and deliberately drops the Imagination/OP-TEE/optee
includes used by the R-Car target.

---

## 4. Guest DTB / boot-device wiring (important TODO)

`fstab.trout_xenvm` references partitions by-name
(`/dev/block/by-name/{system,vendor,userdata,...}`). For the guest to mount
them, `androidboot.boot_devices` in
[`xenvm_rpi5_arm64/BoardConfig.mk`](xenvm_rpi5_arm64/BoardConfig.mk) must match
how Xen presents the Android disk(s) to the guest.

* Current placeholder: `androidboot.boot_devices=virtio` (line ~67).
* If Xen exposes the disk as a xen vbd (`/dev/xvda*`), change it to `xvda`
  (or whichever the guest actually sees), and ensure the guest DTB + Xen
  domain config create the matching by-name links.

Verify on first boot via serial:

```text
# in the guest shell
ls -l /dev/block/by-name/
cat /proc/cmdline    # confirm androidboot.boot_devices=...
```

Adjust `BOARD_BOOTCONFIG += androidboot.boot_devices=...` in
[`xenvm_rpi5_arm64/BoardConfig.mk`](xenvm_rpi5_arm64/BoardConfig.mk) and
rebuild `vendor_boot`/`boot` as needed.

---

## 5. Xen domain config (DomU)

Adapt the approach from xen-troops/meta-xt-prod-devel-rpi5 issue #71 (Android
14) to Android 17. High level:

* Provide the built **guest DTB** (`bcm2712-rpi-5-xen.dtb`) to the domain,
  either via dom0less in the hypervisor device tree or via `xl` with
  `device_tree=...`.
* Map the Android disk image(s) as `disk = [ 'phy:/dev/...,xvda,w' ]` (or
  virtio-blk) so the by-name scheme above matches.
* Map a virtio-gpu / framebuffer for `drm_hwcomposer`, vsock for VHAL
  (`cid=2 port=9210` — the Dom0 VHAL server side must be running), and a
  vuart/console for early serial.
* Kernel = the `Image` from step 2; initramfs / vendor_boot from the Android
  build (ramdisk with the loaded `*.ko`).

Your separate `meta-xt-prod-devel-rpi5` tree already has the RPi5 Xen
hypervisor + Dom0 + guest DTB plumbing; reuse it and only swap in the Android
17 guest kernel + Android images produced here.

---

## 6. First-boot validation checklist

* [ ] `repo sync` clean (no Renesas/Imagination auth errors)
* [ ] `lunch aosp_xenvm_rpi5_arm64-trunk_staging-userdebug` selects
      `TARGET_PRODUCT=aosp_xenvm_rpi5_arm64`, `TARGET_CPU_VARIANT=cortex-a76`,
      `TARGET_BOARD_PLATFORM=bcm2712`
* [ ] Build completes; `TARGET_PREBUILT_KERNEL` / `TARGET_PREBUILT_MODULES_DIR`
      picked up (check `out/target/product/xenvm_rpi5_arm64/` for the kernel +
      loaded modules)
* [ ] Guest boots under Xen; serial console shows Android init
* [ ] `logcat` reachable (vsock/adb over the configured transport)
* [ ] `/dev/block/by-name/*` resolves (fix `androidboot.boot_devices`)
* [ ] VHAL vsock connection to Dom0 (`cid=2 port=9210`) establishes
* [ ] Graphics via mesa/drm_hwcomposer on virtio-gpu renders

---

## 7. Sharing with other developers

The `rj/xenBringup` branch (manifest repo **and** device repo) carries all the
changes. After you push both branches:

```bash
repo init -u <manifest-remote> -b rj/xenBringup
repo sync
```

Other developers then follow sections 2–5 above. No Renesas/Imagination
credentials are required for the RPi5 target.
