## Summary

> **This kernel patch is a mainline candidate and will be submitted to linux-mmc shortly.** It is carried here only until it lands upstream, and should be dropped the moment it does. It is not a ROCKNIX-specific workaround — it fixes a generic `drivers/mmc/core/sd.c` bug that affects any device with an SD card, and is written as an upstream submission (failure logs, rejected alternatives, no device-specific conditionals).

This addresses @sydarn's point on #3220 about being uneasy carrying custom mmc patches. Agreed — the intent was always to report these upstream, and splitting them out here makes that easier to track independently of the rk817 work.

* **0008 — a failed resume is reported as success.** `_mmc_sd_resume()` hands its result to `mmc_sd_runtime_resume()`, which logs it and returns 0, so the PM core is told the resume worked even though the card was never brought back. Every queued request then waits forever: jbd2, the writeback worker and the block queue end up in uninterruptible sleep, and on a boot medium that takes the whole machine down — userspace stops responding while the kernel carries on answering pings. Retry once from a clean slate after a power cycle.
* **99-automount** — a card that drops off the bus leaves its mounts behind with the filesystem shut down. The add rule then sees the stale entry in `/proc/mounts`, skips the remount, and the card stays unusable until reboot even though the kernel re-detected it immediately. Clear them on removal.

### The second patch was dropped after hardware testing (2026-09-11)

This PR previously also carried `0007-mmc-sd-do-not-fail-card-init-when-the-cache-cannot-be.patch`, which made a failed SD "Cache Enable" write non-fatal to card init. Testing on the RG353M that produced the original failure removed it:

* The patch fired exactly as designed — `could not enable card cache (-110), continuing without it` — and the card was **still** removed 0.16 ms later, because the post-resume presence check found it unresponsive. ext4 aborted its journal, and only the automount rule above brought the card back.
* Worse, by turning the init error into a success it stopped `0008`'s retry from ever running.
* Rebuilt without it, the same card on the same device hit the same trigger and the retry recovered it with the mount intact.

The cache failure is therefore not a separate bug needing its own fix. It is one more way a resume fails, and the retry covers it. What is broken at that moment is the card's state, not the return value, so suppressing the error only hides it from the code that can repair it.

## Testing

Two triggers, two devices, two cards — the retry handles both.

* **Card still busy when the host re-initialises it** — GKD Pixel2 (PX30), boot/root card, kernel 7.1.2. 8 rapid suspend/resume cycles reproduced the failure twice, and the retry recovered the card both times at SDR104: no card removal, no ext4 or journal errors, no D-state tasks, root filesystem verified read-write seconds after each recovery. Unpatched, the same sequence wedges the machine until a hard reset.
* **Card times out the optional cache-enable write** — Anbernic RG353M (RK3566), games card (Phison, manfid `0x000027`, oemid `0x5048`, 03/2025), ext4, kernel 7.0.2, 2026-09-11. With the retry alone: the trigger fired, the retry fired 11 µs later, the card was back and re-tuned 212 ms later, and for that whole boot there were **0 card removals, 0 ext4 aborts and 0 failed retries**. The mount never left `/proc/mounts` and userspace never re-ran its automount, so the filesystem was never torn down.
* Applies at strict zero fuzz (`-F0`) across every kernel in the tree: 6.18.45 (RK3399), 7.0.2 (RK3566/76), 7.1.2 (RK3326) and 7.2 (H700/SM6115/SM8xxx), and to mainline 7.3-rc3.

## Additional Context

* **Not device-specific.** The trigger on the Pixel2 is a card still busy when host re-init starts — dw_mmc waits 500 ms for DAT0 and then issues the command regardless, and a card is entitled to be busy longer than that. The trigger on the RG353M is an optional feature failing to enable. Any card can hit either; the handhelds just suspend and resume far more often than most hardware.
* Raising dw_mmc's busy timeout was considered instead and rejected: that poll is `readl_poll_timeout_atomic()`, so a longer wait means spinning longer in atomic context, and it would only help one host driver.
* `mainline/` rather than `mainline-rockchip/` deliberately — this benefits every device with an SD card, not just the Rockchip ones.

---

### AI Usage

**Did you use AI tools to help write this code?** PARTIALLY

