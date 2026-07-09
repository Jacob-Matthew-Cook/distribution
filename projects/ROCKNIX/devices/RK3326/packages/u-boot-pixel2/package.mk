# SPDX-License-Identifier: GPL-2.0
# Copyright (C) 2024-present ROCKNIX (https://github.com/ROCKNIX)

PKG_NAME="u-boot-pixel2"
PKG_VERSION=""
PKG_LICENSE="GPL"
PKG_SITE=""
PKG_URL=""
PKG_LONGDESC="Hybrid bootloader for the GKD Pixel 2 (RK3326S): vendor idbloader/trust plus ROCKNIX's own U-Boot proper"
PKG_DEPENDS_TARGET="u-boot"
PKG_TOOLCHAIN="manual"

# The GKD Pixel 2's vendor U-Boot 2017.09 fork has a `source`/`cfgload`
# bug that reads garbage instead of a supplied boot.ini - confirmed via
# direct memory-dump inspection against a live device: the legacy image
# header, CRC, architecture field and script data are all byte-perfect
# and correctly positioned, yet `source` still reads from the wrong
# address. Rather than keep fighting an unobservable bug in closed-source
# vendor firmware, this package keeps only the vendor's idbloader (SPL -
# trains this board's LPDDR4 memory, per the "LP4,1024MB,333MHz" the
# vendor firmware itself reports, which ROCKNIX's own rkbin DDR blob is
# not confirmed to support) and resource/trust image (BL31/OP-TEE), and
# swaps in ROCKNIX's own U-Boot proper - the same one that already
# correctly runs extlinux/source for subdevices a/b - for the interactive
# boot-script layer. BL31 hands off to U-Boot proper via a standard,
# non-board-specific ARM Trusted Firmware entry point (0x00200000), so
# this boundary is not vendor-locked. c_boot.ini/c_boot.scr generation is
# handled generically by the "u-boot" package itself (see its
# config/c_boot.ini), the same as a_boot.ini/b_boot.ini - this package
# only needs to assemble the combined pre-partition-table blob.
makeinstall_target() {
  mkdir -p ${INSTALL}/usr/share/bootloader

  cat idbloader.img "$(get_build_dir u-boot)/uboot.img.default" resource.img > ${INSTALL}/usr/share/bootloader/c_uboot.bin
}
