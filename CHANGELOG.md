Changelog

[1.3] - 2026-10-02  ⚗️⚡

Fixed
- Windows .bat: pressing Enter at a prompt no longer re-uses the previous answer (menu choice, YES confirmation, slot, checksum).
- Flash ROM (.sh and .bat) now stops at the first failed step instead of continuing to reboot and sideload.
- Checksum verifier in the .bat no longer shows the previous file's hash.
- Performance-pass resume file is now per-device (.sh). Two phones no longer skip each other's apps.
- Screenshot file names no longer depend on the Windows regional date format.
- Failed screenshots no longer leave an empty file behind.
- Deep clean handles folder names with spaces (.sh).

Added
- Restore stock shows the connected device's product name and asks before running.
- Phones in recovery, unauthorized or offline state are detected and explained instead of showing "not connected".
- bash 4 check with a clear message on macOS, and a shasum fallback for checksums.
- Typed paths accept quotes, ~ and drag-and-drop in both scripts.

Changed
- Uninstall command is now:
  rm -f ~/flask-adb-toolkit.sh
  find ~ -maxdepth 1 -name '.flask-adb-compile-progress*' -delete
  (avoids the glob tantrum in fish and other strict shells)
- Windows performance pass now tells you the android.auto_generated_rro_* failure lines are harmless.

[1.2] - Skipped
(Too many errors. Not worth the bandwidth.)

[1.1] - 2026-09-30

Added
- Performance pass now skips un-compilable system packages.
- Auto-resume if interrupted.

Changed
- Improved ROM auto-detection order.

[1.0] - Never released
Deleted by accident while trying to tidy the lab. The flask slipped. These things happen when you have no body and still attempt file management.
