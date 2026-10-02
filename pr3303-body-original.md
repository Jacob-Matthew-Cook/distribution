## Summary

Three dwc2 fixes plus the userspace role handling that goes with the last one. All root-caused on a GKD Pixel 2 (PX30/RK3326) from pstore/ramoops captures.

* **003 — gadget NULL deref on resume.** `dwc2_restore_device_registers()` dereferences `hsotg->eps_in[i]`/`eps_out[i]` for every endpoint with `EPENA` set, but on cores with dedicated-direction endpoints (`GHWCFG1 dev_ep_dirs`) only one direction per endpoint number is allocated, so the opposite slot is NULL. Reachable on every resume where the controller power domain was off during suspend; the oops lands in the device-resume phase, so userspace never thaws and the machine hangs. On PX30 `dev_ep_dirs = 0x6664`, so `eps_in[2] == NULL`.
* **004 — hard hang suspending after a failed core reset.** If `dwc2_core_reset()` times out the core never leaves soft reset, and the suspend path still backs up the device registers unconditionally. With the UTMI clock domain dead those reads do not fail — they stall the AHB and wedge the CPU. No oops; only a watchdog recovers it. Skip the save/restore when the reset failed.
* **035 — vbus-supply leaked leaving host mode (RK3326).** dwc2 releases `vbus-supply` only via `_dwc2_hcd_stop()`/`_dwc2_hcd_suspend()` or the Connector ID B-device path. A `usb-role-switch` driven change out of host mode takes neither: `dwc2_drd_role_sw_set()` forces device mode and returns, the HCD is never stopped, so the port keeps driving 5V while in device mode. Release it when the new role is not host.
* **usbgadget** — single-port boards that also charge through the OTG port cannot park in host mode, since dwc2 keeps sourcing 5V and the PMIC never sees a charger. Follow the ID pin via the usb2phy's `USB-HOST` extcon instead, gated on the new `DEVICE_USB_ROLE_FOLLOW_ID` quirk so no other device changes behaviour.

Split out of #3220 at @porschemad911's suggestion, so each change is independently reviewable rather than one oversized PR. Every file here is unchanged from #3220 and has been hardware-tested on the affected devices; that PR itemizes every change and carries the full test record. 003/004 and 035+usbgadget are kept together because the role-switch fix is what makes the charging path work, and it is the same subsystem and the same hardware.

## Testing

* Both crash fixes verified on the previously 100%-reproducing hardware (GKD Pixel 2). 004 reproduced 100% before the fix: boot on battery with no USB cable, then enter system suspend.
* 035 root-caused from a sysfs trace of the role switch, the usb2phy `USB-HOST` extcon and the RK817 `otg_switch` regulator — `otg_switch` stayed enabled after leaving host mode until reboot. Full trace is in the patch header.
* Patches apply cleanly to both kernels shipped for these devices (7.1.2 RK3326, 7.0.2 RK3566).
* Full test record is in #3220, where these were developed; the files here are unchanged from it.

## Additional Context

* **Released builds are not affected by the 003/004 crashes.** Latest stable (20260901) was tested on the Pixel 2 with no crashes, despite shipping the same 7.1.2 dwc2 code without these fixes — the triggering conditions are not met there. These are latent-bug fixes and hardening, not a regression fix, so they can be scheduled accordingly.
* `035` depends on `010-dwc2-track-vbus-supply-state.patch`, which is already in `RK3326/patches/linux/` — the exit helper is reference counted there, so the release is a no-op when nothing is held.
* `mainline-rockchip/` starts at 003 here; 001/002/005 are the rk817 patches still in #3220 and will follow in a later PR. Gaps are consistent with the existing `mainline/` set, which starts at 0002 and skips 0006.
* `usbgadget` reads the quirk file directly rather than via the environment, since it also runs from udev on extcon changes where the login environment is absent.

---

### AI Usage

**Did you use AI tools to help write this code?** PARTIALLY



