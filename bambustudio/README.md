<!-- SPDX-FileCopyrightText: 2026 Travis Lyons -->
<!-- SPDX-License-Identifier: 0BSD -->

# Bambu Studio

Packages the official x86_64 Ubuntu 24.04 AppImage, extracted into
`/usr/lib/bambustudio` with resources under `/usr/share/bambustudio`.
Launch with `bambu-studio` or the Bambu Studio desktop entry.
FUSE is not required at build time or runtime. The bundled FFmpeg libraries stay
private; ELF RUNPATHs use `$ORIGIN` instead of upstream's build directory and
current-directory lookup. The launcher retains upstream's `LC_ALL=C` workaround.

Based on the [AUR bambustudio-bin package](https://aur.archlinux.org/packages/bambustudio-bin).
Unlike that recipe, this release already links to WebKitGTK 4.1 and does not need
its older WebKitGTK/libsoup replacement patches. Dependencies are based on the
release's ELF requirements and runtime library/tool loading; neither OpenVDB nor
Wayland protocol build definitions are needed. There is no conflict with
`squashfuse`. Optional `gst-plugins-bad` supplies H.264 support for the
GStreamer-based printer camera viewer.

Bambu Studio is AGPL-3.0-only; its bundled FFmpeg libraries report
LGPL-2.1-or-later. The optional proprietary Bambu networking plugin is not
included. It can be downloaded by the application; without it, sliced files can
be transferred to a printer using an SD card.

## Updating

This package intentionally has no Renovate annotation: release asset names
include a timestamp that cannot be derived from the version, and upstream also
publishes tags without release assets. Version-only updates would be broken.

1. Select a published release with an Ubuntu 24.04 x86_64 AppImage.
2. Update `pkgver` and `_buildstamp` together; reset `pkgrel` to `1`.
3. Run `updpkgsums`, compare the AppImage SHA-256 with the GitHub release asset's
   digest, and regenerate `.SRCINFO` with `makepkg --printsrcinfo > .SRCINFO`.
4. Recheck ELF dependencies and run the repository's lint/build validation.

## Validation notes

`check()` validates the desktop entry and runs the application CLI help without
requiring a display server. Local testing of 02.08.02.61 also verified the
packaged launcher, STL inspection, and GUI startup using an isolated home and
virtual X server. Printer and networking-plugin functionality were not tested.
Local clean-chroot validation was unavailable because non-interactive sudo was
unavailable; the required pull-request CI job remains authoritative.

Known findings for this upstream release:

- Reopening a minimal CLI-exported 3MF with `--info` crashes, including with the
  unmodified upstream AppImage. STL inspection works; this is not a packaging
  regression.
- Namcap reports missing FULL RELRO in upstream's prebuilt FFmpeg libraries.
  Fixing that requires rebuilding those libraries.
- Namcap mistakes the application's `info/*.json` resources for GNU info pages
  and cannot detect runtime use of `libxkbcommon`, `xdg-utils`, or CA certificate
  data. These dependencies are intentional.
- On first GUI startup, upstream may ask to use the system CA certificate store.
  `SSL_CERT_FILE=/etc/ssl/cert.pem bambu-studio` explicitly selects Arch's store
  if desired; certificate verification is not disabled.
