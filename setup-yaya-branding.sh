#!/usr/bin/env bash
# ============================================================
# Yaya OS — Branding de ARRANQUE (no toca XFCE)
#   · Identidad del sistema: os-release, hostname, issue, motd
#   · Splash de arranque (Plymouth): lockup Yaya Tech CENTRADO
#   · Logo del SO = solo el alien (icono distributor-logo)
#
# Deliberadamente NO cambia: wallpaper, tema, panel ni greeter de
# XFCE. Solo el arranque y la identidad del sistema.
#
#   Uso manual:  sudo ./setup-yaya-branding.sh
#   En live-build: config/hooks/live/0520-yaya-branding.hook.chroot
# ============================================================
set -euo pipefail

OS_NAME="Yaya OS"
OS_ID="yaya"
OS_VERSION="2.0"
OS_CODENAME="alien"
OS_HOME="https://yaya.tech"
OS_SUPPORT="https://yaya.cash"

ICON_HICOLOR=/usr/share/icons/hicolor
PLYMOUTH_DIR=/usr/share/plymouth/themes/yaya
export DEBIAN_FRONTEND=noninteractive

# --- localizar los SVG de marca (junto al script, o en /usr/share/yaya) ---
SELF_DIR="$(cd "$(dirname "$0")" && pwd)"
if   [ -d "$SELF_DIR/branding" ];        then ART="$SELF_DIR/branding"
elif [ -d /usr/share/yaya/branding ];    then ART=/usr/share/yaya/branding
else echo "ERROR: no encuentro los SVG de branding"; exit 1; fi

echo "==> [1/6] Dependencias de render (temporales)"
apt-get update
apt-get install -y --no-install-recommends \
  librsvg2-bin plymouth plymouth-themes hostname

# rsvg-convert -> PNG.  Los SVG ya llevan el texto como VECTOR (no <text>),
# así que no dependen de ninguna fuente instalada.
render() { install -d "$(dirname "$4")"; rsvg-convert -w "$2" -h "$3" "$1" -o "$4"; }

echo "==> [2/6] Logo del SO = alien (icono 'distributor-logo')"
for S in 16 22 24 32 48 64 128 256; do
  render "$ART/yaya-logo.svg" "$S" "$S" "$ICON_HICOLOR/${S}x${S}/apps/distributor-logo.png"
  render "$ART/yaya-logo.svg" "$S" "$S" "$ICON_HICOLOR/${S}x${S}/apps/start-here.png"
  render "$ART/yaya-logo.svg" "$S" "$S" "$ICON_HICOLOR/${S}x${S}/apps/yaya-logo.png"
done
install -Dm644 "$ART/yaya-logo.svg" "$ICON_HICOLOR/scalable/apps/yaya-logo.svg"
gtk-update-icon-cache -f "$ICON_HICOLOR" 2>/dev/null || true

# Reemplazar la BANDERA DE WINDOWS del set de iconos activo por el alien Yaya.
# El tema Windows-10-Icons trae su propio distributor-logo/start-here en places/
# y, por ser el tema activo, gana sobre hicolor -> aparecía el logo de Microsoft.
WICONS=/usr/share/icons/Windows-10-Icons
if [ -d "$WICONS" ]; then
  # PNG en cada tamaño existente (deriva el px del nombre de carpeta NxN)
  while IFS= read -r f; do
    px=$(basename "$(dirname "$(dirname "$f")")"); px=${px%%x*}
    case "$px" in ''|*[!0-9]*) continue;; esac
    render "$ART/yaya-logo.svg" "$px" "$px" "$f"
  done < <(find "$WICONS" -type f \( -name 'distributor-logo.png' -o -name 'start-here.png' \))
  # SVG no simbólicos (los -symbolic se dejan; GTK los recolorea)
  while IFS= read -r f; do
    cp "$ART/yaya-logo.svg" "$f"
  done < <(find "$WICONS" -type f \( -name 'distributor-logo.svg' -o -name 'start-here.svg' \))
  gtk-update-icon-cache -f "$WICONS" 2>/dev/null || true
fi

echo "==> [3/6] Identidad del SO (/etc/os-release, lsb-release)"
cat > /usr/lib/os-release <<EOF
PRETTY_NAME="${OS_NAME} ${OS_VERSION} (${OS_CODENAME})"
NAME="${OS_NAME}"
VERSION_ID="${OS_VERSION}"
VERSION="${OS_VERSION} (${OS_CODENAME})"
VERSION_CODENAME=${OS_CODENAME}
BUILD_ID="${OS_VERSION}-$(date -u +%Y%m%d)"
ID=${OS_ID}
ID_LIKE=debian
HOME_URL="${OS_HOME}"
SUPPORT_URL="${OS_SUPPORT}"
BUG_REPORT_URL="${OS_SUPPORT}"
LOGO=yaya-logo
EOF
ln -sf ../usr/lib/os-release /etc/os-release
echo "Yaya OS ${OS_VERSION} build $(date -u +%Y%m%d-%H%M) UTC" > /etc/yaya-version
cat > /etc/lsb-release <<EOF
DISTRIB_ID=${OS_NAME}
DISTRIB_RELEASE=${OS_VERSION}
DISTRIB_CODENAME=${OS_CODENAME}
DISTRIB_DESCRIPTION="${OS_NAME} ${OS_VERSION}"
EOF

echo "==> [4/6] Hostname, issue y motd"
echo "$OS_ID" > /etc/hostname
printf '%s \\n \\l\n\n' "${OS_NAME} ${OS_VERSION}" > /etc/issue
printf '%s\n' "${OS_NAME} ${OS_VERSION}"           > /etc/issue.net
cat > /etc/motd <<EOF

  ${OS_NAME} — soberanía digital sobre hardware honesto
  Soporte: ${OS_SUPPORT}   ·   Wallets: Electrum (BTC) · Feather (XMR)

EOF

echo "==> [5/6] Splash de arranque (Plymouth): lockup Yaya Tech centrado"
# Logo (lockup transparente) a alta resolución -> el script lo centra y
# escala al tamaño de pantalla, nítido en cualquier resolución.
render "$ART/yaya-logo-full.svg" 2000 1104 "$PLYMOUTH_DIR/logo.png"
cat > "$PLYMOUTH_DIR/yaya.plymouth" <<EOF
[Plymouth Theme]
Name=Yaya OS
Description=Yaya Tech boot splash
ModuleName=script

[script]
ImageDir=${PLYMOUTH_DIR}
ScriptFile=${PLYMOUTH_DIR}/yaya.script
EOF
cat > "$PLYMOUTH_DIR/yaya.script" <<'PLY'
# --- fondo negro a pantalla completa ---
sw = Window.GetWidth();  sh = Window.GetHeight();
Window.SetBackgroundTopColor(0.0, 0.0, 0.0);
Window.SetBackgroundBottomColor(0.0, 0.0, 0.0);

# --- lockup centrado, escalado al ~48% del ancho de pantalla ---
logo = Image("logo.png");
lw = logo.GetWidth();  lh = logo.GetHeight();
target_w = sw * 0.48;
scale = target_w / lw;
logo = logo.Scale(lw * scale, lh * scale);
logo_spr = Sprite(logo);
logo_spr.SetX(sw / 2 - (lw * scale) / 2);
logo_spr.SetY(sh / 2 - (lh * scale) / 2);
logo_spr.SetZ(10);

# --- puntos de progreso bajo el lockup (color alien #cfd4da) ---
n = 5;  dots = [];
for (i = 0; i < n; i++) {
  d = Image.Text(".", 0.81, 0.83, 0.85);
  s = Sprite(d);
  s.SetX(sw / 2 - (n * 12) / 2 + i * 24);
  s.SetY(sh / 2 + (lh * scale) / 2 + 24);
  s.SetZ(11);
  dots[i] = s;
}
tick = 0;
fun refresh() {
  tick++;
  for (i = 0; i < n; i++)
    dots[i].SetOpacity(((Math.Int(tick / 6) % n) == i) ? 1 : 0.25);
}
Plymouth.SetRefreshFunction(refresh);

# --- prompt de contraseña (LUKS / login) bajo los puntos ---
fun on_pw(prompt, bullets) {
  txt = Image.Text(prompt + "  " + bullets, 1, 1, 1);
  p = Sprite(txt);
  p.SetX(sw / 2 - txt.GetWidth() / 2);
  p.SetY(sh / 2 + (lh * scale) / 2 + 60);
  p.SetZ(12);
}
Plymouth.SetDisplayPasswordFunction(on_pw);
PLY

if command -v plymouth-set-default-theme >/dev/null; then
  plymouth-set-default-theme -R yaya 2>/dev/null \
    || plymouth-set-default-theme yaya || true
fi
update-initramfs -u 2>/dev/null || true
# NOTA: en el chroot LIVE no existe /etc/grub.d ni /etc/default/grub (grub no
# está instalado). Toda la config del GRUB instalado se hace en yaya-postinstall,
# que el preseed corre CON `in-target` cuando grub YA está instalado en el disco.

# --- Post-instalación: se ejecuta en el sistema INSTALADO (in-target) ---
#   · grub silencioso + timeout + magenta  · apt sin medio live
# No se aplica al Live (allí manda live-config con el usuario 'user').
cat > /usr/local/sbin/yaya-postinstall <<'PI'
#!/bin/sh
set -e
USR="${1:-yaya}"

# 1) (sin autologin: SDDM preselecciona al usuario creado)

# 2) GRUB instalado: arranque silencioso (sin verbose) + timeout corto
if [ -f /etc/default/grub ]; then
  sed -i 's|^#\?GRUB_CMDLINE_LINUX_DEFAULT=.*|GRUB_CMDLINE_LINUX_DEFAULT="quiet splash loglevel=3 vt.global_cursor_default=0"|' /etc/default/grub
  sed -i 's|^#\?GRUB_TIMEOUT=.*|GRUB_TIMEOUT=3|' /etc/default/grub
  grep -q '^GRUB_TIMEOUT=' /etc/default/grub || echo 'GRUB_TIMEOUT=3' >> /etc/default/grub
fi

# 3) Colores magenta en el menú GRUB instalado
if [ -d /etc/grub.d ]; then
  cat > /etc/grub.d/09_yaya_colors <<'GC'
#!/bin/sh
echo "set color_normal=magenta/black"
echo "set color_highlight=white/magenta"
echo "set menu_color_normal=magenta/black"
echo "set menu_color_highlight=white/magenta"
GC
  chmod +x /etc/grub.d/09_yaya_colors
fi

# 4) Quitar la fuente APT del medio live (apt limpio en el instalado)
sed -i '\|file:/run/live/medium|d' /etc/apt/sources.list 2>/dev/null || true

update-grub 2>/dev/null || true
PI
chmod +x /usr/local/sbin/yaya-postinstall

echo "==> [6/6] Limpieza de dependencias de render"
apt-get purge -y librsvg2-bin >/dev/null 2>&1 || true
apt-get autoremove -y >/dev/null 2>&1 || true

echo ""
echo "Branding de arranque aplicado (escritorio intacto):"
echo "  Identidad : ${OS_NAME} ${OS_VERSION} (${OS_CODENAME})"
echo "  Splash    : Plymouth 'yaya' — lockup Yaya Tech centrado sobre negro"
echo "  Logo SO   : alien (icono distributor-logo / start-here)"
