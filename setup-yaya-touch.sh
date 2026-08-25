#!/usr/bin/env bash
# ============================================================
# Yaya OS — táctil, stylus y touchpad: lo maneja GNOME
#
# GNOME 48 sobre Wayland ya trae, de fábrica y sin extensiones:
#   · Teclado en pantalla que aparece solo al tocar un campo de texto
#     (y se va solo) — no hace falta maliit/onboard.
#   · Gestos multitáctiles y swipes de borde (mutter).
#   · Auto-rotación por acelerómetro y modo tablet — sólo necesita
#     iio-sensor-proxy, que es lo único que instalamos aquí.
#   · Stylus completo (presión, botones, mapeo por pantalla) en
#     Ajustes → Tableta gráfica / Wacom.
#
# Este hook por tanto NO configura el táctil: sólo pone las piezas de
# hardware que GNOME necesita y unos defaults de touchpad vía dconf.
#   En live-build: config/hooks/live/0530-yaya-touch.hook.chroot
# ============================================================
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

echo "==> [1/4] Piezas de hardware que GNOME necesita"
apt-get update
apt-get install -y --no-install-recommends \
  iio-sensor-proxy \
  xserver-xorg-input-libinput libinput-tools

echo "==> [2/4] Sin overrides de X11: libinput + GNOME deciden"
# Reglas heredadas de la etapa XFCE/Plasma; si quedaron, estorban.
rm -f /etc/X11/xorg.conf.d/40-yaya-touch.conf

echo "==> [3/4] Defaults de touchpad/ratón (dconf, modificables por el usuario)"
install -d /etc/dconf/db/local.d
cat > /etc/dconf/db/local.d/20-yaya-input <<'EOF'
# Yaya OS — punteros. Defaults, no locks: Ajustes → Ratón y touchpad manda.

[org/gnome/desktop/peripherals/touchpad]
tap-to-click=true
natural-scroll=true
two-finger-scrolling-enabled=true
disable-while-typing=true
click-method='fingers'
send-events='enabled'

[org/gnome/desktop/peripherals/mouse]
# En un ratón el scroll natural desconcierta; en el touchpad no.
natural-scroll=false
accel-profile='default'
EOF
dconf update

echo "==> [4/4] Servicios"
systemctl enable iio-sensor-proxy.service 2>/dev/null || true
echo "Táctil listo: GNOME se encarga (rotación, teclado en pantalla, gestos, stylus)."
