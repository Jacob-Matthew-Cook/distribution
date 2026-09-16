# SPDX-License-Identifier: GPL-2.0
# Copyright (C) 2024-present ROCKNIX (https://github.com/ROCKNIX)

PKG_NAME="suspend-stub"
PKG_VERSION="1.0"
PKG_LICENSE="GPL-2.0-or-later"
PKG_SITE="https://github.com/kailashrs/H700_rocknix_enhancement"
PKG_URL=""
PKG_DEPENDS_TARGET="toolchain"
PKG_LONGDESC="SRAM resume stub for H700 system suspend: puts DRAM in self-refresh and brings it back."
PKG_TOOLCHAIN="manual"

# The DRAM sources are U-Boot's own, taken from the bootloader package's
# unpacked tree. Source only: a target dependency here would close the loop
# u-boot -> atf -> suspend-stub -> u-boot.
PKG_DEPENDS_UNPACK="u-boot-DDR4 u-boot-DDR3 atf"
PKG_NEED_UNPACK="$(get_pkg_directory u-boot-DDR4) $(get_pkg_directory u-boot-DDR3)"

# One stub per memory type; BL31 picks the match at boot. <bootloader package>:<output>
PKG_STUB_VARIANTS="u-boot-DDR4:suspend_stub_lpddr4.bin \
                   u-boot-DDR3:suspend_stub_lpddr3.bin"

stub_variant() {
  local uboot="${1}" out="${2}" dir="${PKG_BUILD}/${2%.bin}"
  local uboot_dir="$(get_build_dir ${uboot})"
  local kconfig="${uboot_dir}/arch/arm/mach-sunxi/Kconfig"
  local defconfig type mstr timings clk sym val

  # the defconfig comes from the bootloader package so the two can never disagree
  defconfig="$(sed -n 's/^[[:space:]]*PKG_UBOOT_CONFIG="\([^"]*\)".*/\1/p' \
                 "$(get_pkg_directory ${uboot})/package.mk" | head -1)"
  [ -n "${defconfig}" ] || die "suspend-stub: no PKG_UBOOT_CONFIG in ${uboot}"
  [ -r "${uboot_dir}/configs/${defconfig}" ] ||
    die "suspend-stub: ${defconfig} not found in ${uboot}"
  defconfig="${uboot_dir}/configs/${defconfig}"

  case "$(grep -oE 'CONFIG_SUNXI_DRAM_H616_[A-Z0-9_]+' ${defconfig} | head -1)" in
    *LPDDR4)   type=8; mstr="(1 << 5)"; timings=h616_lpddr4_2133.c ;;
    *LPDDR3)   type=7; mstr="(1 << 3)"; timings=h616_lpddr3.c ;;
    *) die "suspend-stub: no known DRAM type in ${defconfig}" ;;
  esac

  mkdir -p ${dir}/src/dram ${dir}/boards
  cp -r ${PKG_BUILD}/src/*.c ${PKG_BUILD}/src/*.S ${PKG_BUILD}/src/*.h ${dir}/src/
  cp ${uboot_dir}/arch/arm/mach-sunxi/dram_sun50i_h616.c \
     ${uboot_dir}/arch/arm/mach-sunxi/dram_dw_helpers.c ${dir}/src/dram/
  cp ${uboot_dir}/arch/arm/mach-sunxi/dram_timings/${timings} ${dir}/src/dram/dram_timing.c
  patch -d ${dir}/src/dram -p1 <${PKG_BUILD}/dram-resume.patch

  grep -E '^CONFIG_(DRAM_|SUNXI_DRAM_H616_)' ${defconfig} |
    sed -e 's/=y$/ 1/' -e 's/=/ /' -e 's/^/#define /' >${dir}/boards/board.h
  grep -q "^#define CONFIG_DRAM_CLK " ${dir}/boards/board.h ||
    die "suspend-stub: no CONFIG_DRAM_CLK found in ${defconfig}"

  # Only unconditional numeric Kconfig defaults: "default X if Y" is per-SoC and
  # would bake in another chip's value. Bools are tested with #ifdef.
  for sym in $(grep -ohE 'CONFIG_DRAM_[A-Z0-9_]+' ${dir}/src/*.[ch] ${dir}/src/dram/*.c | sort -u); do
    if grep -q "^#define ${sym} " ${dir}/boards/board.h; then
      continue
    fi
    val="$(awk -v s="config ${sym#CONFIG_}" '$0 == s { f = 1; next }
             f && /^config / { exit }
             f && /^\tbool/ { print "bool"; exit }
             f && /^\tdefault / {
               if ($0 !~ / if / && $2 ~ /^(0x[0-9a-fA-F]+|[0-9]+)$/) print $2
               exit }' ${kconfig})"
    [ "${val}" = bool ] && continue
    [ -n "${val}" ] ||
      die "suspend-stub: the DRAM code reads ${sym}, but ${defconfig##*/} does not set it and its Kconfig default is not usable here"
    echo "#define ${sym} ${val}" >>${dir}/boards/board.h
  done

  echo "#define STUB_DRAM_TYPE ${type}" >>${dir}/boards/board.h
  echo "#define STUB_MSTR_DEVICETYPE ${mstr}" >>${dir}/boards/board.h

  # TF-A matches on (type, clk); two stubs sharing both would be picked arbitrarily
  clk="$(awk '$2 == "CONFIG_DRAM_CLK" { print $3 }' ${dir}/boards/board.h)"
  if grep -qx "${type} ${clk}" ${PKG_BUILD}/.stub-keys; then
    die "suspend-stub: ${out} is DRAM type ${type} at ${clk} MHz, same as an earlier stub; TF-A could not tell them apart"
  fi
  echo "${type} ${clk}" >>${PKG_BUILD}/.stub-keys

  ( cd ${dir}
    local cflags="-I$(get_build_dir atf)/plat/allwinner/sun50i_h616/include -I${PKG_BUILD}/compat -Iboards \
      -I${uboot_dir}/arch/arm/include/asm/arch-sunxi \
      -include ${PKG_BUILD}/compat/stub_compat.h -include boards/board.h \
      -Os -std=gnu11 -march=armv8-a -mgeneral-regs-only \
      -mstrict-align -mcmodel=small -ffreestanding -fno-builtin -fno-pic -fno-pie \
      -fno-stack-protector -fno-common -ffunction-sections -fdata-sections \
      -Wall -Wno-unused-function"
    ${TARGET_KERNEL_PREFIX}gcc -march=armv8-a -D__ASSEMBLY__ -c src/start.S -o start.o
    for c in src/main.c src/lib.c src/clock.c src/dram_sr.c \
             src/dram/dram_sun50i_h616.c src/dram/dram_dw_helpers.c src/dram/dram_timing.c; do
      ${TARGET_KERNEL_PREFIX}gcc ${cflags} -c ${c} -o $(basename ${c} .c).o
    done
    ${TARGET_KERNEL_PREFIX}gcc -march=armv8-a -mgeneral-regs-only -ffreestanding -nostdlib \
      -static -no-pie -Wl,--gc-sections -Wl,-T,${PKG_BUILD}/stub.lds -Wl,--build-id=none \
      start.o main.o lib.o clock.o dram_sr.o dram_sun50i_h616.o dram_dw_helpers.o dram_timing.o \
      -o stub.elf
    ${TARGET_KERNEL_PREFIX}objcopy -O binary stub.elf ${PKG_BUILD}/${out} )
}

make_target() {
  : >${PKG_BUILD}/.stub-keys
  for v in ${PKG_STUB_VARIANTS}; do
    stub_variant "${v%:*}" "${v##*:}"
  done
}

makeinstall_target() {
  : # atf embeds the stubs in bl31; nothing from this package is installed
}
