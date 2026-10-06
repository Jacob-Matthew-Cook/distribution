# SPDX-License-Identifier: GPL-2.0
# Copyright (C) 2024-present ROCKNIX (https://github.com/ROCKNIX)

PKG_NAME="h700-suspend-stub"
PKG_VERSION="712653d11230b2450061ddb8e25f31e072da7a48"
PKG_SHA256="3698da9aad40c26c10f6aa31f8366158914e0a351d31f1084c6b8032147f4616"
PKG_LICENSE="GPL-2.0-or-later"
PKG_SITE="https://github.com/Jacob-Matthew-Cook/h700-suspend-stub"
PKG_URL="https://github.com/Jacob-Matthew-Cook/h700-suspend-stub/archive/${PKG_VERSION}.tar.gz"
PKG_DEPENDS_TARGET="toolchain"
PKG_LONGDESC="SRAM suspend stub for PSCI SYSTEM_SUSPEND on the H700, by kailashrs."
PKG_TOOLCHAIN="manual"

# The DRAM sources are U-Boot's own, taken from the bootloader package's
# unpacked tree. Source only: a target dependency here would close the loop
# u-boot -> atf -> suspend-stub -> u-boot.
PKG_DEPENDS_UNPACK="u-boot atf"
PKG_NEED_UNPACK="$(get_pkg_directory u-boot) $(get_pkg_directory atf)"

# One stub per memory type; BL31 picks the match at boot. <u-boot defconfig>:<output>
PKG_STUB_VARIANTS="anbernic_rg35xx_h700_lpddr4_defconfig:suspend_stub_lpddr4.bin \
                   anbernic_rg35xx_h700_lpddr3_defconfig:suspend_stub_lpddr3.bin"

make_target() {
  local variant out dir defconfig key

  : >${PKG_BUILD}/.stub-keys
  for variant in ${PKG_STUB_VARIANTS}; do
    defconfig="$(get_build_dir u-boot)/configs/${variant%:*}"; out="${variant##*:}"; dir="${PKG_BUILD}/${out%.bin}"
    [ -r "${defconfig}" ] || die "suspend-stub: ${defconfig} not found"

    mkdir -p ${dir}
    make -C ${dir} -f ${PKG_BUILD}/Makefile SRC_DIR=${PKG_BUILD} UBOOT_DIR=$(get_build_dir u-boot) \
      ATF_DIR=$(get_build_dir atf) DEFCONFIG=${defconfig} OUT=${out} CROSS_COMPILE=${TARGET_KERNEL_PREFIX}

    # TF-A matches on (type, clk); two stubs sharing both would be picked arbitrarily
    key="$(awk '$2 == "STUB_DRAM_TYPE" || $2 == "CONFIG_DRAM_CLK" { printf "%s ", $3 }' ${dir}/boards/board.h)"
    grep -qx "${key}" ${PKG_BUILD}/.stub-keys &&
      die "suspend-stub: ${out} is DRAM type/clock ${key}, same as an earlier stub; TF-A could not tell them apart"
    echo "${key}" >>${PKG_BUILD}/.stub-keys
  done
}

makeinstall_target() {
  # atf reads the stubs from the sysroot rather than from this build directory,
  # which neither survives AUTOREMOVE nor crosses a CI job boundary.
  mkdir -p ${SYSROOT_PREFIX}/usr/share/${PKG_NAME}
  cp -a *.bin ${SYSROOT_PREFIX}/usr/share/${PKG_NAME}
}
