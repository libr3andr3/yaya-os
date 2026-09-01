#!/usr/bin/env bash
# ============================================================
# Yaya OS — soporte táctil (Plasma 6 / Wayland)
#   · Auto-rotación: iio-sensor-proxy (KWin/kscreen la usan nativamente)
#   · Teclado en pantalla: maliit-keyboard (se activa en /etc/xdg/kwinrc)
#   · Touchpad: lo gestiona Plasma (yaya-input-defaults fija scroll natural + tap)
#   · Gestos: nativos de KWin Wayland (3/4 dedos), sin touchegg.
#   En live-build: config/hooks/live/0530-yaya-touch.hook.chroot
# ============================================================
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

echo "==> [1/3] Paquetes táctiles"
apt-get update
apt-get install -y --no-install-recommends \
  iio-sensor-proxy maliit-keyboard \
  xserver-xorg-input-libinput libinput-tools

echo "==> [2/3] Touchpad/rotación/gestos: los gestiona Plasma (sin overrides X11)"
rm -f /etc/X11/xorg.conf.d/40-yaya-touch.conf

echo "==> [3/3] Servicios"
systemctl enable iio-sensor-proxy.service 2>/dev/null || true
echo "Soporte táctil listo (Plasma Wayland: rotación, teclado virtual, gestos nativos)."
