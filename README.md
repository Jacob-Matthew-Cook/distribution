# Upstreaming #3303 (dwc2)

Everything needed to send the kernel parts of #3303 to linux-usb. The ROCKNIX PR carries the code with one-line subjects. The full commit messages, logs and test record are kept here.

ROCKNIX commit: `31a12cde4a` on `dwc2-usb-fixes`. The development history and hardware captures are in #3220 (closed 2026-10-01).

## Files

| File | What it is |
|---|---|
| `patches/003-usb-dwc2-gadget-fix-null-deref-on-register-restore.patch` | 003 before the cleanup, with the full commit message and oops log |
| `patches/004-usb-dwc2-skip-pm-callbacks-after-failed-core-reset.patch` | 004 before the cleanup, with the full commit message |
| `patches/035-dwc2-release-vbus-supply-on-role-switch.patch` | 035 before the cleanup, with the role-switch trace |
| `patches/010-dwc2-track-vbus-supply-state.patch` | sunshineinabox's 010 from `RK3326/patches/linux`, unchanged. 035 depends on it. |
| `pr3303-commit-message-original.txt` | The original ROCKNIX commit message |
| `pr3303-body-original.md` | The original PR body, with the test record |

## Patches

| Patch | Upstream fit | Notes |
|---|---|---|
| 003 `usb: dwc2: gadget: Fix NULL pointer dereference in dwc2_restore_device_registers()` | Good | Self-contained, 2 lines. Message and `Cc: stable` already written. |
| 004 `usb: dwc2: Skip PM register save/restore if the core reset timed out` | Good | Self-contained. Reviewers may ask whether `dwc2_core_reset()` callers should handle the error instead of a sticky flag. |
| 035 `usb: dwc2: release vbus-supply when a role switch leaves host mode` | Needs work | Depends on 010. Has no From/Date/Subject header and no `Signed-off-by:`. The message needs ROCKNIX wording removed: drop the "Not from upstream" opener, refer to 010 by its subject rather than its file name, say "userspace" rather than `usbgadget`, and drop "reference counted" (010 is a boolean enabled flag). |
| 010 `usb: dwc2: track vbus-supply enable state` | Not ours | sunshineinabox wrote it (commit "rk3326: fix dwc2 enable count underflow", merged in #3008). Either he sends it, or it goes in the series with his `Signed-off-by:`. |
| `usbgadget` follow-ID role, GKD Pixel2 quirk | ROCKNIX only | Userspace, stays in ROCKNIX. |

## Where to send

| Maintainer | List | Tree |
|---|---|---|
| Minas Harutyunyan `<hminas@synopsys.com>` (dwc2) | `linux-usb@vger.kernel.org` | |
| Greg Kroah-Hartman `<gregkh@linuxfoundation.org>` (USB) | `linux-usb@vger.kernel.org` | `gregkh/usb.git`: `usb-linus` for fixes, `usb-next` otherwise |

Minas and the list are from the DESIGNWARE USB2 DRD IP DRIVER entry in the 7.2 MAINTAINERS file; its `T:` line still names the old `balbi/usb.git`. Greg and his tree are from the USB SUBSYSTEM entry. Run `scripts/get_maintainer.pl` on the final patches for the full Cc list.

## Before sending

1. Rebase on `usb.git`, not on 7.0/7.1, and generate the patches with `git format-patch` so each has a proper header.
2. Make `scripts/checkpatch.pl --strict` clean.
3. Add your `Signed-off-by:` to every patch. 003 and 004 have it; 035 doesn't.
4. Add `Assisted-by:` to every patch where AI was used. `Documentation/process/submitting-patches.rst` ("Using Assisted-by") requires it, and `coding-assistants.rst` gives the format. None of the three has one yet.
5. Keep `Cc: stable@vger.kernel.org` on 003 and 004, and add `Fixes:` tags where the commits that introduced the bugs can be found.
6. Send one series: 003 and 004, plus 010 and 035 if sunshineinabox agrees.
7. Talk to sydarn and macromorgan first. The #3220 closing comment says the USB-OTG work will be discussed with them.
