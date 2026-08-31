#!/usr/bin/env bash
# ============================================================
# Yaya OS — soporte táctil (GNOME / Wayland)
#   · Auto-rotación: iio-sensor-proxy (GNOME Shell la usa nativamente)
#   · Teclado en pantalla: el OSK integrado de GNOME (sin paquetes extra)
#   · Touchpad: lo gestiona GNOME (dconf de setup-yaya-gnome.sh fija
#     scroll natural + tap-to-click)
#   · Gestos: nativos de GNOME Shell (3/4 dedos), sin touchegg.
#   En live-build: config/hooks/live/0530-yaya-touch.hook.chroot
# ============================================================
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

echo "==> [1/3] Paquetes táctiles"
apt-get update
apt-get install -y --no-install-recommends \
  iio-sensor-proxy \
  xserver-xorg-input-libinput libinput-tools

echo "==> [2/3] Touchpad/rotación/gestos: los gestiona GNOME (sin overrides X11)"
rm -f /etc/X11/xorg.conf.d/40-yaya-touch.conf

echo "==> [3/3] Servicios"
systemctl enable iio-sensor-proxy.service 2>/dev/null || true
echo "Soporte táctil listo (GNOME Wayland: rotación, teclado virtual, gestos nativos)."
