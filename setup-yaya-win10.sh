#!/usr/bin/env bash
# ============================================================
# Yaya OS — XFCE con apariencia Windows 10
# Debian 12/13 (bookworm/trixie)
# Uso: sudo ./setup-yaya-win10.sh  (luego re-login)
# En live-build: copiar como hook a config/hooks/live/
# ============================================================
set -euo pipefail

THEME_DIR=/usr/share/themes
ICON_DIR=/usr/share/icons
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

echo "==> [1/5] Paquetes base XFCE"
export DEBIAN_FRONTEND=noninteractive
apt-get update
# NOTA: sin "2>/dev/null || true" — si el escritorio o el display manager
# no instalan, el build DEBE fallar ruidosamente (antes daba ISO sin GUI).
apt-get install -y --no-install-recommends \
  xfce4 xfce4-whiskermenu-plugin xfce4-pulseaudio-plugin \
  xfce4-power-manager xfce4-notifyd xfce4-screenshooter \
  network-manager-gnome thunar thunar-archive-plugin \
  mousepad ristretto xfce4-taskmanager \
  fonts-open-sans git curl unzip \
  lightdm lightdm-gtk-greeter plank-

# X server COMPLETO: metapaquete xserver-xorg + TODOS los drivers de entrada
# y video. Con --no-install-recommends el server base quedaba sin drivers de
# entrada -> "sin mouse" (trackpad no enlazaba). Esto maximiza compatibilidad.
echo "==> [1b/6] Drivers de entrada y video (fix 'sin mouse')"
apt-get install -y --no-install-recommends \
  xserver-xorg xserver-xorg-input-all xserver-xorg-video-all \
  firmware-misc-nonfree

echo "==> [2/5] Tema GTK Windows-10 (B00merang, GPL)"
git clone --depth 1 https://github.com/B00merang-Project/Windows-10.git \
  "$TMP/win10-theme"
rm -rf "$THEME_DIR/Windows-10"
cp -r "$TMP/win10-theme" "$THEME_DIR/Windows-10"
# limpiar metadatos git de la ISO
rm -rf "$THEME_DIR/Windows-10/.git"

echo "==> [3/5] Iconos Windows-10 (B00merang-Artwork, GPL)"
git clone --depth 1 https://github.com/B00merang-Artwork/Windows-10.git \
  "$TMP/win10-icons"
rm -rf "$ICON_DIR/Windows-10-Icons"
cp -r "$TMP/win10-icons" "$ICON_DIR/Windows-10-Icons"
rm -rf "$ICON_DIR/Windows-10-Icons/.git"
gtk-update-icon-cache -f "$ICON_DIR/Windows-10-Icons" || true

echo "==> [4/5] Config XFCE por defecto (skel para nuevos usuarios)"
# Los XML de xfce-perchannel-xml deben acompañar este script en ./skel/
if [ -d "$(dirname "$0")/skel" ]; then
  cp -r "$(dirname "$0")/skel/." /etc/skel/
fi

# Aplicar también al usuario actual si no es root puro (instalación manual)
if [ -n "${SUDO_USER:-}" ] && [ "$SUDO_USER" != "root" ]; then
  USER_HOME=$(getent passwd "$SUDO_USER" | cut -d: -f6)
  cp -r "$(dirname "$0")/skel/." "$USER_HOME/"
  chown -R "$SUDO_USER:$SUDO_USER" "$USER_HOME/.config"
fi

echo "==> [5/5] LightDM greeter con el mismo tema"
mkdir -p /etc/lightdm
cat > /etc/lightdm/lightdm-gtk-greeter.conf <<'EOF'
[greeter]
theme-name = Windows-10
icon-theme-name = Windows-10-Icons
font-name = Open Sans 10
indicators = ~host;~spacer;~clock;~spacer;~session;~power
clock-format = %H:%M
EOF

echo "==> [6/6] Arranque gráfico (fix del 'sin GUI')"
# En el chroot, el postinst de lightdm crea el alias display-manager.service
# pero NO el symlink de arranque (graphical.target.wants). Sin esto systemd
# llega a graphical.target y NADIE levanta el DM -> consola, sin escritorio.
systemctl set-default graphical.target || true
systemctl enable lightdm.service || true
# Cinturón y tirantes: asegurar el 'wants' aunque el enable no lo cree en chroot
mkdir -p /etc/systemd/system/graphical.target.wants
ln -sf /lib/systemd/system/lightdm.service \
  /etc/systemd/system/graphical.target.wants/display-manager.service 2>/dev/null || true
# Marcar lightdm como el DM por defecto para el debconf/selector
echo "/usr/sbin/lightdm" > /etc/X11/default-display-manager

echo ""
echo "Listo. Escritorio XFCE (Win10) + LightDM habilitado en graphical.target."
echo "Tema: Windows-10 | Iconos: Windows-10-Icons | Panel: abajo, estilo Win10"
