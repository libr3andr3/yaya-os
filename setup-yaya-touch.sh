#!/usr/bin/env bash
# ============================================================
# Yaya OS — soporte táctil (Plasma 6 / Wayland)
#   · Auto-rotación: iio-sensor-proxy (KWin/kscreen la usan nativamente)
#   · Teclado en pantalla: maliit-keyboard (se activa en /etc/xdg/kwinrc)
#   · Touchpad: tap-to-click + scroll natural (X11 fallback via xorg.conf.d;
#     en Wayland KWin ya usa libinput con tap habilitado por defecto en Plasma 6)
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

echo "==> [2/3] Touchpad (X11): tap-to-click y scroll natural"
install -d /etc/X11/xorg.conf.d
cat > /etc/X11/xorg.conf.d/40-yaya-touch.conf <<'EOF'
Section "InputClass"
    Identifier "yaya touchpad"
    MatchIsTouchpad "on"
    Driver "libinput"
    Option "Tapping" "on"
    Option "NaturalScrolling" "true"
    Option "ClickMethod" "clickfinger"
EndSection
EOF

echo "==> [3/3] Servicios"
systemctl enable iio-sensor-proxy.service 2>/dev/null || true
echo "Soporte táctil listo (Plasma Wayland: rotación, teclado virtual, gestos nativos)."
