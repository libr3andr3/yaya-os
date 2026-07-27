#!/usr/bin/env bash
# ============================================================
# Yaya OS — Soporte táctil para XFCE (opcional)
#   Teclado en pantalla que auto-aparece · auto-rotación ·
#   gestos multitáctiles · tap-to-click.
#
#   OPCIONAL: solo tiene sentido en equipos con pantalla táctil
#   (convertibles / 2-en-1). En un desktop normal, el teclado en
#   pantalla podría aparecer sin querer — por eso NO está cableado
#   por defecto en yaya-flash.sh. Actívalo con:
#     config/hooks/live/0530-yaya-touch.hook.chroot
#   o manualmente:  sudo ./setup-yaya-touch.sh
#
#   Nota: XFCE nunca será tan "seamless" como Plasma/GNOME en táctil.
#   Para una flota mayoritariamente táctil, ver TOUCHSCREEN.md.
# ============================================================
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

echo "==> [1/5] Paquetes táctiles"
apt-get update
apt-get install -y --no-install-recommends \
  onboard onboard-common \
  iio-sensor-proxy \
  xinput x11-xserver-utils libinput-tools \
  xserver-xorg-input-libinput \
  xdotool wmctrl

echo "==> [2/5] Teclado en pantalla (Onboard) con auto-show por defecto"
# Defaults del sistema vía dconf para TODOS los usuarios nuevos.
install -d /etc/dconf/db/local.d /etc/dconf/profile
cat > /etc/dconf/profile/user <<'EOF'
user-db:user
system-db:local
EOF
cat > /etc/dconf/db/local.d/00-yaya-onboard <<'EOF'
# Onboard: aparece solo al enfocar un campo de texto, se oculta al teclear
[org/onboard]
auto-show=true
xembed-onboard=false
start-minimized=true

[org/onboard/auto-show]
enabled=true
hide-on-key-press=true

[org/onboard/window]
docking-enabled=true
force-to-top=true
EOF
dconf update 2>/dev/null || true

# Onboard SOLO en hardware táctil: un wrapper detecta un dispositivo de toque
# antes de lanzarlo, así en un desktop normal el teclado nunca aparece.
cat > /usr/local/bin/yaya-onboard-if-touch <<'OB'
#!/usr/bin/env bash
# Lanza Onboard solo si hay una pantalla táctil conectada.
command -v xinput >/dev/null || exit 0
if xinput --list --name-only 2>/dev/null | grep -qiE 'touchscreen|finger|touch'; then
  exec onboard
fi
exit 0
OB
chmod +x /usr/local/bin/yaya-onboard-if-touch

install -d /etc/skel/.config/autostart
cat > /etc/skel/.config/autostart/onboard.desktop <<'EOF'
[Desktop Entry]
Type=Application
Name=Teclado en pantalla (solo táctil)
Exec=/usr/local/bin/yaya-onboard-if-touch
OnlyShowIn=XFCE;
X-GNOME-Autostart-enabled=true
NoDisplay=true
EOF

echo "==> [3/5] Auto-rotación (acelerómetro -> pantalla + panel táctil)"
cat > /usr/local/bin/yaya-autorotate <<'ROT'
#!/usr/bin/env bash
# Mapea la orientación del acelerómetro a xrandr + matriz de los
# dispositivos de entrada táctiles. Requiere iio-sensor-proxy.
set -euo pipefail
OUT="$(xrandr --query | awk '/ connected/{print $1; exit}')"
[ -n "${OUT:-}" ] || exit 0
declare -A ROT=( [normal]=normal [bottom-up]=inverted [left-up]=left [right-up]=right )
declare -A MTX=(
  [normal]="1 0 0 0 1 0 0 0 1"
  [bottom-up]="-1 0 1 0 -1 1 0 0 1"
  [left-up]="0 -1 1 1 0 0 0 0 1"
  [right-up]="0 1 0 -1 0 1 0 0 1"
)
monitor-sensor 2>/dev/null | while read -r line; do
  case "$line" in
    *"Accelerometer orientation changed"*)
      o="${line##*: }"
      [ -n "${ROT[$o]:-}" ] || continue
      xrandr --output "$OUT" --rotate "${ROT[$o]}"
      # aplicar la misma transformación a cada dispositivo táctil/lápiz
      xinput --list --name-only | while read -r dev; do
        case "$dev" in
          *[Tt]ouch*|*[Ss]tylus*|*[Pp]en*|*[Ff]inger*|*Wacom*)
            xinput set-prop "$dev" "Coordinate Transformation Matrix" ${MTX[$o]} 2>/dev/null || true ;;
        esac
      done ;;
  esac
done
ROT
chmod +x /usr/local/bin/yaya-autorotate

cat > /etc/skel/.config/autostart/yaya-autorotate.desktop <<'EOF'
[Desktop Entry]
Type=Application
Name=Yaya auto-rotación
Exec=/usr/local/bin/yaya-autorotate
OnlyShowIn=XFCE;
X-GNOME-Autostart-enabled=true
NoDisplay=true
EOF

echo "==> [4/5] Gestos multitáctiles (touchegg)"
if apt-get install -y --no-install-recommends touchegg >/dev/null 2>&1; then
  systemctl enable touchegg.service 2>/dev/null || true
  install -d /etc/skel/.config/touchegg
  cat > /etc/skel/.config/touchegg/touchegg.conf <<'EOF'
<touchegg>
  <settings>
    <property name="animation_delay">150</property>
    <property name="action_execute_threshold">20</property>
  </settings>
  <application name="All">
    <!-- 3 dedos arriba: mostrar el escritorio (Win+D) -->
    <gesture type="SWIPE" fingers="3" direction="UP">
      <action type="RUN_COMMAND"><command>xdotool key super+d</command><repeat>false</repeat></action>
    </gesture>
    <!-- 3 dedos izq/der: cambiar de escritorio -->
    <gesture type="SWIPE" fingers="3" direction="LEFT">
      <action type="RUN_COMMAND"><command>xdotool set_desktop --relative -- 1</command><repeat>false</repeat></action>
    </gesture>
    <gesture type="SWIPE" fingers="3" direction="RIGHT">
      <action type="RUN_COMMAND"><command>xdotool set_desktop --relative -- -1</command><repeat>false</repeat></action>
    </gesture>
    <!-- 3 dedos abajo: cambiar de ventana (Alt+Tab) -->
    <gesture type="SWIPE" fingers="3" direction="DOWN">
      <action type="RUN_COMMAND"><command>xdotool key alt+Tab</command><repeat>false</repeat></action>
    </gesture>
  </application>
</touchegg>
EOF
fi

echo "==> [5/5] Entrada libinput: tap-to-click y scroll natural por defecto"
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

echo ""
echo "Soporte táctil aplicado (XFCE):"
echo "  Teclado en pantalla : Onboard (auto-show al enfocar texto)"
echo "  Auto-rotación       : yaya-autorotate (iio-sensor-proxy)"
echo "  Gestos              : touchegg (3 dedos, pellizco)"
echo "  Touchpad            : tap-to-click + scroll natural"
echo ""
echo "  Recuerda: para una experiencia táctil REALMENTE seamless,"
echo "  considera un build con KDE Plasma. Ver TOUCHSCREEN.md."
