#!/usr/bin/env bash
# ============================================================
# Yaya OS — Calamares graphical installer
#   · Installs Calamares + the Yaya settings/branding/modules
#   · International: user picks country/region/timezone + keyboard
#   · Adds an "Install Yaya OS" launcher (desktop + autostart)
#
#   Uso manual:  sudo ./setup-yaya-calamares.sh
#   En live-build: config/hooks/live/0560-yaya-calamares.hook.chroot
#
# Espera que los assets del kit ya estén en el chroot:
#   /usr/share/yaya/calamares/{settings.conf,modules/,branding/}
#   /usr/share/yaya/branding/*.svg   (logos vectoriales)
# (yaya-flash.sh los copia vía config/includes.chroot).
# ============================================================
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

SRC=/usr/share/yaya/calamares
ART=/usr/share/yaya/branding
DEST=/etc/calamares

[ -d "$SRC" ] || { echo "ERROR: no encuentro $SRC (¿se copió el kit al chroot?)"; exit 1; }

echo "==> [1/5] Instalando Calamares y utilidades de instalación"
apt-get update
# Calamares + los backends que usan los módulos (partición, unpack, grub).
# Con recommends: arrastra los módulos QML del slideshow.
apt-get install -y \
  calamares \
  squashfs-tools rsync \
  dosfstools e2fsprogs cryptsetup lvm2 \
  grub-pc-bin grub-efi-amd64-bin efibootmgr \
  qml-module-qtquick2 qml-module-qtquick-window2 \
  qml-module-qtquick-layouts qml-module-qtquick-controls2
# Render temporal SVG->PNG (se purga al final). Preferimos rsvg-convert;
# si no está, caemos a ImageMagick (uno u otro DEBE existir).
apt-get install -y --no-install-recommends librsvg2-bin || \
  apt-get install -y --no-install-recommends imagemagick

echo "==> [2/5] Desplegando configuración Yaya en $DEST"
install -d "$DEST" "$DEST/modules" "$DEST/branding"
install -m644 "$SRC/settings.conf" "$DEST/settings.conf"
cp -a "$SRC/modules/." "$DEST/modules/"
cp -a "$SRC/branding/." "$DEST/branding/"

echo "==> [3/5] Rasterizando logos de marca para el instalador"
BR="$DEST/branding/yaya"
install -d "$BR"
# render SRC WxH DEST  (H vacío = alto automático preservando proporción)
render() {
  if command -v rsvg-convert >/dev/null; then
    if [ -n "$3" ]; then rsvg-convert -w "$2" -h "$3" "$1" -o "$4"
    else                 rsvg-convert -w "$2"          "$1" -o "$4"; fi
  else
    if [ -n "$3" ]; then magick -background none "$1" -resize "${2}x${3}" "$4"
    else                 magick -background none "$1" -resize "${2}x"      "$4"; fi
  fi
}
# productIcon + productLogo (cuadrado, alien solo).
render "$ART/yaya-logo.svg" 256 256 "$BR/yaya-logo.png"
# productWelcome + slideshow (lockup alien + "Yaya Tech", transparente).
render "$ART/yaya-logo-full.svg" 512 "" "$BR/yaya-welcome.png"
apt-get purge -y librsvg2-bin 2>/dev/null || true
apt-get autoremove -y || true

echo "==> [4/5] Lanzador 'Install Yaya OS' (menú, escritorio, autostart)"
cat > /usr/share/applications/yaya-install.desktop <<'EOF'
[Desktop Entry]
Type=Application
Version=1.0
Name=Install Yaya OS
GenericName=System Installer
Comment=Install Yaya OS to this computer
Exec=pkexec calamares
Icon=yaya-logo
Terminal=false
StartupNotify=true
Categories=System;
Keywords=calamares;installer;yaya;
EOF

# Autostart al iniciar la sesión live (Calamares detecta si está en vivo).
install -d /etc/skel/.config/autostart
cp /usr/share/applications/yaya-install.desktop \
   /etc/skel/.config/autostart/yaya-install.desktop

# Icono en el escritorio del usuario live (Nemo lo marca como confiable).
install -d /etc/skel/Desktop
cp /usr/share/applications/yaya-install.desktop /etc/skel/Desktop/yaya-install.desktop
chmod +x /etc/skel/Desktop/yaya-install.desktop
gio set /etc/skel/Desktop/yaya-install.desktop metadata::trusted true 2>/dev/null || true

echo "==> [5/5] Regla polkit: Calamares sin pedir contraseña en la sesión live"
install -d /etc/polkit-1/rules.d
cat > /etc/polkit-1/rules.d/49-yaya-calamares.rules <<'EOF'
/* Live session runs as an unprivileged user; allow launching the
   installer via pkexec without a password prompt. */
polkit.addRule(function(action, subject) {
    if (action.id == "org.freedesktop.policykit.exec" &&
        action.lookup("program") == "/usr/bin/calamares") {
        return polkit.Result.YES;
    }
});
EOF

echo "==> Calamares (Yaya OS) listo."
