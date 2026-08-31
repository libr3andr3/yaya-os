#!/usr/bin/env bash
# ============================================================
# Yaya OS — GNOME (Wayland) + GDM3
#   · Reemplaza a Plasma/SDDM (el kit Plasma vive en el historial de git).
#   · Wayland por defecto (mejor táctil/gestos); GDM ofrece la
#     sesión "GNOME on Xorg" como alternativa.
#   · Adwaita oscuro + acento púrpura (el vibe Yaya).
#   · Alien como logo del greeter de GDM (org.gnome.login-screen).
#   · AppIndicator activado: bandeja para Electrum/Feather.
#   · Sin autologin: GDM lista los usuarios locales.
#
#   Uso manual:  sudo ./setup-yaya-gnome.sh
#   En live-build: config/hooks/live/0500-yaya-gnome.hook.chroot
# ============================================================
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

echo "==> [1/4] Paquetes GNOME + GDM3"
apt-get update
# Si el escritorio o GDM fallan, el build DEBE fallar (no ISO sin GUI).
apt-get install -y --no-install-recommends \
  gnome-shell gnome-session gdm3 \
  gnome-control-center gnome-tweaks \
  gnome-shell-extension-appindicator \
  network-manager-gnome \
  xdg-desktop-portal-gnome xdg-desktop-portal-gtk \
  nautilus gnome-console gnome-text-editor gnome-calculator \
  loupe evince file-roller \
  baobab gnome-system-monitor gnome-disk-utility gparted \
  gnome-software gnome-software-plugin-flatpak \
  gnome-keyring \
  pipewire-audio pipewire-pulse wireplumber libspa-0.2-bluetooth \
  xdg-user-dirs fonts-cantarell fonts-noto-core \
  librsvg2-common

echo "==> [2/4] GDM: display manager por defecto, Wayland, alien en el greeter"
echo "/usr/sbin/gdm3" > /etc/X11/default-display-manager
systemctl enable gdm3.service 2>/dev/null || \
  ln -sf /lib/systemd/system/gdm3.service /etc/systemd/system/display-manager.service
install -d /etc/gdm3
cat > /etc/gdm3/daemon.conf <<'EOF'
# Yaya OS — GDM: Wayland por defecto, sin autologin.
[daemon]
WaylandEnable=true
EOF

# Alien en blanco para el greeter (el SVG de marca viene en plata #cfd4da).
BR=/usr/share/yaya/branding
if [ -f "$BR/yaya-logo.svg" ]; then
  sed 's/#cfd4da/#ffffff/gI' "$BR/yaya-logo.svg" > "$BR/yaya-logo-white.svg"
else
  echo "   WARN: falta $BR/yaya-logo.svg; el greeter quedará sin logo"
fi

# Greeter de GDM vía perfil dconf 'gdm' (mecanismo upstream; en Debian
# también existe /etc/gdm3/greeter.dconf-defaults, pero el perfil en
# /etc/dconf gana y no depende de dpkg-reconfigure).
install -d /etc/dconf/profile /etc/dconf/db/gdm.d
printf 'user-db:user\nsystem-db:gdm\n' > /etc/dconf/profile/gdm
cat > /etc/dconf/db/gdm.d/10-yaya <<'EOF'
[org/gnome/login-screen]
logo='/usr/share/yaya/branding/yaya-logo-white.svg'
disable-user-list=false
EOF

echo "==> [3/4] Defaults dconf para usuarios (oscuro, táctil, favoritos, bandeja)"
install -d /etc/dconf/db/local.d
printf 'user-db:user\nsystem-db:local\n' > /etc/dconf/profile/user
cat > /etc/dconf/db/local.d/10-yaya <<'EOF'
# Yaya OS — defaults de escritorio (el usuario puede cambiarlos)
[org/gnome/desktop/interface]
color-scheme='prefer-dark'
accent-color='purple'

[org/gnome/desktop/peripherals/touchpad]
tap-to-click=true
natural-scroll=true

[org/gnome/desktop/wm/preferences]
button-layout='appmenu:minimize,maximize,close'

[org/gnome/shell]
enabled-extensions=['appindicatorsupport@rgcjonas.gmail.com']
favorite-apps=['firefox-esr.desktop','org.gnome.Nautilus.desktop','org.gnome.Console.desktop','org.gnome.TextEditor.desktop','org.gnome.Software.desktop','org.gnome.Settings.desktop']

# Software: sin descargas automáticas (unattended-upgrades ya hace seguridad)
[org/gnome/software]
download-updates=false
EOF
dconf update

echo "==> [4/4] Resumen"
echo "GNOME + GDM3 listo:"
echo "   Sesión   : GNOME (Wayland) por defecto; 'GNOME on Xorg' disponible"
echo "   Greeter  : GDM con alien blanco, lista de usuarios, sin autologin"
echo "   Defaults : Adwaita oscuro, acento púrpura, tap-to-click, AppIndicator"
