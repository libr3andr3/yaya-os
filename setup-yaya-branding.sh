#!/usr/bin/env bash
# ============================================================
# Yaya OS — Branding de ARRANQUE (no toca el escritorio)
#   · Identidad del sistema: os-release, hostname, issue, motd
#   · Splash de arranque (Plymouth): lockup Yaya Tech centrado sobre
#     negro, con barra de progreso debajo
#   · Logo del SO = solo el alien (icono distributor-logo). GNOME lo usa
#     en Ajustes → Acerca de, vía LOGO= de /etc/os-release.
#
# Deliberadamente NO cambia wallpaper, tema ni greeter: de eso se ocupa
# setup-yaya-gnome.sh. Aquí sólo el arranque y la identidad del sistema.
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

echo "==> [5/6] Splash de arranque (Plymouth): alien + barra de progreso"
# Logo (lockup transparente) a alta resolución -> el script lo centra y
# escala al tamaño de pantalla, nítido en cualquier resolución.
render "$ART/yaya-logo-full.svg" 2000 1104 "$PLYMOUTH_DIR/logo.png"
# La barra: Plymouth-script no sabe dibujar rectángulos, así que la
# componemos con dos PNG lisos (400x6) que el script reescala: uno de
# fondo y otro que se recorta al ancho del progreso.
bar_png() { printf '<svg xmlns="http://www.w3.org/2000/svg" width="1" height="1"><rect width="1" height="1" fill="%s"/></svg>' "$2" \
              | rsvg-convert -w 400 -h 6 -o "$PLYMOUTH_DIR/$1"; }
bar_png bar-track.png '#2a3038'
bar_png bar-fill.png  '#cfd4da'
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

# --- lockup centrado, escalado al ~42% del ancho de pantalla ---
logo = Image("logo.png");
lw = logo.GetWidth();  lh = logo.GetHeight();
scale = (sw * 0.42) / lw;
logo_w = lw * scale;  logo_h = lh * scale;
logo_spr = Sprite(logo.Scale(logo_w, logo_h));
logo_spr.SetX(sw / 2 - logo_w / 2);
logo_spr.SetY(sh / 2 - logo_h / 2);
logo_spr.SetZ(10);

# --- barra de progreso DEBAJO del lockup (como el splash de Plasma) ---
bar_w = 260;  bar_h = 6;
bar_x = sw / 2 - bar_w / 2;
bar_y = sh / 2 + logo_h / 2 + 40;

track = Sprite(Image("bar-track.png").Scale(bar_w, bar_h));
track.SetX(bar_x);  track.SetY(bar_y);  track.SetZ(11);

fill_img = Image("bar-fill.png");
fill = Sprite();
fill.SetX(bar_x);  fill.SetY(bar_y);  fill.SetZ(12);

# Plymouth entrega el progreso real del arranque (0..1). Nunca escalamos a
# 0 px de ancho: Image.Scale(0, ...) no produce una imagen válida.
fun on_progress(duration, progress) {
  p = progress;
  if (p < 0.02) p = 0.02;
  if (p > 1)    p = 1;
  fill.SetImage(fill_img.Scale(bar_w * p, bar_h));
}
Plymouth.SetBootProgressFunction(on_progress);

# --- prompt de contraseña (LUKS / login) bajo la barra ---
fun on_pw(prompt, bullets) {
  txt = Image.Text(prompt + "  " + bullets, 1, 1, 1);
  p = Sprite(txt);
  p.SetX(sw / 2 - txt.GetWidth() / 2);
  p.SetY(bar_y + 34);
  p.SetZ(13);
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

# 1) Sin rastro del instalador en el sistema instalado
#    (lanzador de escritorio/autostart/menú, wrapper, regla polkit del live)
rm -f /usr/share/applications/yaya-install.desktop /usr/bin/yaya-install \
      /etc/polkit-1/rules.d/49-yaya-calamares.rules \
      /etc/skel/Desktop/yaya-install.desktop /etc/skel/.config/autostart/yaya-install.desktop
for h in /home/* /root; do
  rm -f "$h/Desktop/yaya-install.desktop" "$h/.config/autostart/yaya-install.desktop"
done
# El instalador estaba de primero en el dash de GNOME sólo en el live:
# fuera, y vuelven los favoritos normales de 00-yaya-desktop.
rm -f /etc/dconf/db/local.d/50-yaya-live-installer
command -v dconf >/dev/null && dconf update || true
# (sin autologin: GDM preselecciona al usuario creado)

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
echo "  Splash    : Plymouth 'yaya' — lockup Yaya Tech + barra de progreso"
echo "  Logo SO   : alien (icono distributor-logo / start-here)"
