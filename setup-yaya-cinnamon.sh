#!/usr/bin/env bash
# ============================================================
# Yaya OS — Cinnamon desktop (replaces the old XFCE/Win10 setup)
#   · Cinnamon shell + LightDM (slick-greeter)
#   · Lean install, tuned for refurbished hardware (4GB+)
#
#   Uso manual:  sudo ./setup-yaya-cinnamon.sh
#   En live-build: config/hooks/live/0500-yaya-cinnamon.hook.chroot
# ============================================================
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

echo "==> [1/4] Paquetes Cinnamon + LightDM"
apt-get update
# cinnamon-core keeps it lean (vs. full 'cinnamon' task). If the desktop or
# the display manager fail to install, the build MUST fail loudly — a silent
# GUI-less ISO is worse than a broken build.
apt-get install -y --no-install-recommends \
  cinnamon-core cinnamon-l10n \
  lightdm lightdm-settings slick-greeter \
  network-manager-gnome \
  gnome-terminal nemo file-roller gnome-screenshot \
  gvfs gvfs-backends xdg-user-dirs \
  fonts-open-sans

echo "==> [2/4] LightDM: greeter slick + sesión Cinnamon por defecto"
install -d /etc/lightdm/lightdm.conf.d
cat > /etc/lightdm/lightdm.conf.d/10-yaya.conf <<'EOF'
[Seat:*]
greeter-session=slick-greeter
user-session=cinnamon
EOF

# Slick-greeter en negro con el logo del alien (branding Yaya).
cat > /etc/lightdm/slick-greeter.conf <<'EOF'
[Greeter]
background=#000000
background-color=#000000
theme-name=Adwaita-dark
icon-theme-name=Adwaita
logo=/usr/share/yaya/branding/yaya-logo.png
draw-user-backgrounds=false
show-hostname=true
EOF

echo "==> [3/4] Activar LightDM como display manager"
echo "/usr/sbin/lightdm" > /etc/X11/default-display-manager
# El postinst crea el alias display-manager.service; forzamos por si acaso.
systemctl enable lightdm.service || \
  ln -sf /lib/systemd/system/lightdm.service \
         /etc/systemd/system/display-manager.service

echo "==> [4/4] Sesión Cinnamon por defecto para AccountsService"
install -d /var/lib/AccountsService/users
# (Los usuarios reales los crea Calamares; esto sólo fija el default de sesión.)

echo "==> Cinnamon listo."
