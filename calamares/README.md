# Yaya OS — Calamares installer kit

Graphical installer for Yaya OS, replacing the old debian-installer preseed.
International and interactive: the user chooses country/region, timezone,
language, and keyboard layout (US by default). Desktop is **KDE Plasma 6**.

## Layout

```
calamares/
  settings.conf          # module sequence + install behaviour
  modules/*.conf         # per-module config (locale, keyboard, partition, …)
  branding/yaya/         # branding.desc, stylesheet.qss, show.qml (slideshow)
  setup-yaya-calamares.sh# chroot hook: installs Calamares + deploys this kit
../setup-yaya-plasma.sh  # chroot hook: Plasma 6 desktop + SDDM + Fluent Round
```

At build time `yaya-flash.sh` copies this tree into the live chroot at
`/usr/share/yaya/calamares`, then `setup-yaya-calamares.sh` (hook 0560):

1. `apt install calamares` + partition/unpack/grub tooling,
2. deploys `settings.conf` → `/etc/calamares/`, `modules/` and `branding/`,
3. rasterizes the brand SVGs (`/usr/share/yaya/branding/*.svg`) into
   `/etc/calamares/branding/yaya/` (`yaya-logo.png`, `yaya-welcome.png`),
4. installs an **Install Yaya OS** launcher (menu + desktop + autostart) and a
   polkit rule so the live user can launch it without a password.

## Install flow (sequence)

welcome → locale → keyboard → partition → users → summary → *(install)* →
finished. Encryption (LUKS2) is offered but **optional** — the old preseed
forced it; here it's the user's choice.

## Branding

Silver alien `#cfd4da` on pure black `#000000`, "Yaya Tech" lockup.
Product name/version pulled from the Yaya OS `os-release`.

## Notes / follow-ups

- Earlier desktop kits (XFCE/Win10, Cinnamon, Plasma) and the old d-i
  preseed + binary hooks were removed from the tree; they live in git history.
- Debian Trixie ships Calamares 3.3.14 (branding format used here is compatible).
