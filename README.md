# Upstreaming #3304 (mmc)

Everything needed to send the kernel part of #3304 to linux-mmc. The ROCKNIX PR carries the code with a one-line subject. The full commit message, logs and test record are kept here.

ROCKNIX commit: `587bc39c5d` on `mmc-sd-resume-fixes`. The development history and hardware captures are in #3220 (closed 2026-10-01).

## Files

| File | What it is |
|---|---|
| `patches/0008-mmc-sd-retry-a-failed-resume-after-a-power-cycle.patch` | 0008 before the cleanup, with the full commit message and both failure logs |
| `pr3304-commit-message-original.txt` | The original ROCKNIX commit message, including why the cache-enable patch was dropped |
| `pr3304-body-original.md` | The original PR body, with the test record |

## Patches

| Patch | Upstream fit | Notes |
|---|---|---|
| 0008 `mmc: core: Retry a failed SD card resume after a power cycle` | Good | Self-contained. Has `Cc: stable` and `Assisted-by: Claude:claude-fable-5-1`, no `Signed-off-by:`. |
| `99-automount.rules` remove handling | ROCKNIX only | udev, stays in ROCKNIX. |

## Where to send

| Maintainer | List | Tree |
|---|---|---|
| Ulf Hansson `<ulfh@kernel.org>` | `linux-mmc@vger.kernel.org` | `ulfh/mmc.git`: `fixes` for fixes, `next` otherwise |

This is the MULTIMEDIA CARD (MMC), SECURE DIGITAL (SD) AND SDIO SUBSYSTEM entry in the 7.2 MAINTAINERS file. Run `scripts/get_maintainer.pl` on the final patch for the full Cc list.

## Before sending

1. Rebase on `mmc.git`, not on 7.0/7.1, and generate the patch with `git format-patch`.
2. Make `scripts/checkpatch.pl --strict` clean.
3. Add your `Signed-off-by:`. `Documentation/process/coding-assistants.rst` says AI agents must not add it; only a human can certify the DCO.
4. Keep `Assisted-by:` and `Cc: stable@vger.kernel.org`, and add a `Fixes:` tag if the commit that made `mmc_sd_runtime_resume()` drop the resume error can be found.
5. Send it on its own, not in the dwc2 series.
6. Talk to sydarn and macromorgan first. The #3220 closing comment says the SD card work will be discussed with them.
