# SPDX-License-Identifier: GPL-2.0-or-later
# Copyright (C) 2026-present ROCKNIX (https://github.com/ROCKNIX)

PKG_NAME="armgba-lr"
PKG_VERSION="b16004a06f2373cf87c0797f2520bfec2fa38c8b"
PKG_LICENSE="GPLv2"
PKG_SITE="https://github.com/Jacob-Matthew-Cook/armGBA"
PKG_URL="${PKG_SITE}/archive/${PKG_VERSION}.tar.gz"
PKG_DEPENDS_TARGET="toolchain"
PKG_LONGDESC="armGBA is a Game Boy Advance, Game Boy and Game Boy Color emulator built around a recompiler for ARM and x86 handhelds."
PKG_TOOLCHAIN="cmake"

makeinstall_target() {
  mkdir -p ${INSTALL}/usr/lib/libretro
  cp ${PKG_BUILD}/.${TARGET_NAME}/armgba_libretro.so ${INSTALL}/usr/lib/libretro/
  cp ${PKG_BUILD}/libretro/armgba_libretro.info ${INSTALL}/usr/lib/libretro/
}
