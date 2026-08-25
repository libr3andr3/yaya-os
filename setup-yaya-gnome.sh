#!/usr/bin/env bash
# ============================================================
# Yaya OS — GNOME 48 (Wayland) + GDM, con marca Yaya
#   · Reemplaza a KDE Plasma 6 / SDDM (y antes a Cinnamon/XFCE).
#   · GNOME de Debian SIN parchar: mismo escritorio que un install
#     por defecto de Debian 13. GNOME se encarga solo del táctil,
#     los gestos, la rotación y el teclado en pantalla.
#   · La marca se aplica SÓLO por los caminos que GNOME soporta:
#     dconf (system db), logo de GDM, wallpaper propio, tema de
#     cursor. Nada de parchar gresources ni temas de shell — eso
#     se rompe en cada actualización de GNOME.
#
#   Uso manual:  sudo ./setup-yaya-gnome.sh
#   En live-build: config/hooks/live/0500-yaya-gnome.hook.chroot
# ============================================================
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

BR=/usr/share/yaya/branding
BG=/usr/share/backgrounds/yaya
# Bibata Modern Ice: cursor blanco de bordes redondeados, GPL-3.0 (redistribuible).
# Pinneado: build reproducible, y si la descarga falla caemos a Adwaita.
BIBATA_VERSION=v2.0.7
BIBATA_THEME=Bibata-Modern-Ice

# --- assets de marca (junto al script, o ya en el chroot) ---
SELF_DIR="$(cd "$(dirname "$0")" && pwd)"
if   [ -d "$SELF_DIR/branding" ];     then ART="$SELF_DIR/branding"
elif [ -d "$BR" ];                    then ART="$BR"
else echo "ERROR: no encuentro los SVG de branding"; exit 1; fi

echo "==> [1/8] Paquetes: GNOME 48 + GDM"
apt-get update
# gnome-core = el escritorio GNOME oficial de Debian (shell, mutter, GDM,
# Files, Console, Software, Settings, portales, visor de fotos/PDF...).
# Si el escritorio falla, el build DEBE fallar: no queremos una ISO sin GUI.
apt-get install -y \
  gnome-core gdm3 dconf-cli

# Extras que un Debian desktop trae y que aquí sí queremos, pero que no
# deben tumbar el build si cambian de nombre entre releases.
for p in \
  gnome-tweaks gnome-shell-extension-manager \
  gnome-browser-connector gnome-firmware \
  xdg-desktop-portal-gnome xdg-desktop-portal-gtk \
  qt6-gtk-platformtheme qt5-gtk-platformtheme \
  fonts-cantarell fonts-noto-core fonts-noto-color-emoji \
  xdg-user-dirs xdg-user-dirs-gtk \
  pipewire-audio pipewire-pulse wireplumber libspa-0.2-bluetooth ; do
  apt-get install -y --no-install-recommends "$p" >/dev/null 2>&1 \
    || echo "   WARN: $p no disponible, omitido"
done

# Herramientas temporales para armar los assets (se purgan al final).
apt-get install -y --no-install-recommends librsvg2-bin curl ca-certificates xz-utils

echo "==> [2/8] GDM como display manager (Wayland por defecto)"
echo "/usr/sbin/gdm3" > /etc/X11/default-display-manager
systemctl enable gdm3.service 2>/dev/null \
  || ln -sf /lib/systemd/system/gdm3.service /etc/systemd/system/display-manager.service
# Restos de la etapa Plasma/SDDM si esto corre sobre una máquina ya instalada.
apt-get purge -y sddm sddm-theme-breeze maliit-keyboard 2>/dev/null || true
rm -rf /etc/sddm.conf.d /usr/share/sddm/themes/Fluent

echo "==> [3/8] Alien blanco + wallpaper de marca"
install -d "$BR" "$BG"
# El SVG de marca viene en plata (#cfd4da); para GDM y el logo del shell
# queremos blanco puro sobre el fondo oscuro.
sed 's/#cfd4da/#ffffff/gI' "$ART/yaya-logo.svg" > "$BR/yaya-logo-white.svg"
# Wallpapers: 4K, compuestos por tools/make-wallpaper.py (alien + halo teal).
for v in "" "-light"; do
  src="$ART/yaya-wallpaper${v}.svg"
  [ -f "$src" ] || { echo "ERROR: falta $src"; exit 1; }
  rsvg-convert -w 3840 -h 2160 "$src" -o "$BG/yaya-wallpaper${v}.png"
done
# Registrarlos en Ajustes → Apariencia (y en el selector de fondos).
install -d /usr/share/gnome-background-properties
cat > /usr/share/gnome-background-properties/yaya.xml <<'XML'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE wallpapers SYSTEM "gnome-wp-list.dtd">
<wallpapers>
  <!-- Una sola entrada adaptativa: GNOME usa <filename> en modo claro y
       <filename-dark> en oscuro, igual que los defaults de dconf. -->
  <wallpaper deleted="false">
    <name>Yaya OS</name>
    <filename>/usr/share/backgrounds/yaya/yaya-wallpaper-light.png</filename>
    <filename-dark>/usr/share/backgrounds/yaya/yaya-wallpaper.png</filename-dark>
    <options>zoom</options>
    <shade_type>solid</shade_type>
    <pcolor>#000000</pcolor>
    <scolor>#000000</scolor>
  </wallpaper>
</wallpapers>
XML

echo "==> [4/8] Tema de cursor (${BIBATA_THEME} ${BIBATA_VERSION}, GPL-3.0)"
CURSOR_THEME=Adwaita
TARBALL="/tmp/${BIBATA_THEME}.tar.xz"
URL="https://github.com/ful1e5/Bibata_Cursor/releases/download/${BIBATA_VERSION}/${BIBATA_THEME}.tar.xz"
if curl -fsSL --retry 3 --connect-timeout 20 "$URL" -o "$TARBALL" \
   && tar -xJf "$TARBALL" -C /usr/share/icons \
   && [ -f "/usr/share/icons/${BIBATA_THEME}/cursors/left_ptr" ]; then
  CURSOR_THEME="$BIBATA_THEME"
  echo "   OK: ${BIBATA_THEME} instalado"
else
  echo "   WARN: no se pudo instalar ${BIBATA_THEME}; se queda el cursor Adwaita de GNOME"
fi
rm -f "$TARBALL"

echo "==> [5/8] Defaults de GNOME para todos los usuarios (dconf system db)"
# Este es EL camino soportado: una base dconf de sistema que fija los
# defaults pero deja al usuario cambiarlos (no usamos locks).
install -d /etc/dconf/profile /etc/dconf/db/local.d /etc/dconf/db/gdm.d
cat > /etc/dconf/profile/user <<'EOF'
user-db:user
system-db:local
EOF

# Lanzadores del dash: resolvemos los .desktop que EXISTEN (los nombres
# cambian entre releases de Debian: Console vs Terminal, Loupe vs eog...).
pick_desktop() {
  local d
  for d in "$@"; do
    [ -f "/usr/share/applications/$d" ] && { echo "$d"; return 0; }
  done
  return 0   # ninguno: se omite del dash, sin romper el build
}
TERM_DESKTOP="$(pick_desktop org.gnome.Console.desktop org.gnome.Terminal.desktop)"
FILES_DESKTOP="$(pick_desktop org.gnome.Nautilus.desktop nautilus.desktop)"
SOFTWARE_DESKTOP="$(pick_desktop org.gnome.Software.desktop)"
SETTINGS_DESKTOP="$(pick_desktop org.gnome.Settings.desktop gnome-control-center.desktop)"
FAVS=""
for d in firefox-esr.desktop "$FILES_DESKTOP" "$TERM_DESKTOP" "$SOFTWARE_DESKTOP" "$SETTINGS_DESKTOP"; do
  [ -n "$d" ] && FAVS="${FAVS:+$FAVS, }'$d'"
done

cat > /etc/dconf/db/local.d/00-yaya-desktop <<EOF
# Yaya OS — apariencia y comportamiento por defecto de GNOME.
# Son DEFAULTS, no locks: el usuario puede cambiar todo en Ajustes.

[org/gnome/desktop/interface]
color-scheme='prefer-dark'
accent-color='teal'
cursor-theme='${CURSOR_THEME}'
cursor-size=24
icon-theme='Adwaita'
clock-show-weekday=true
show-battery-percentage=true

[org/gnome/desktop/background]
# GNOME elige por modo: picture-uri en claro, picture-uri-dark en oscuro.
# Arrancamos en oscuro, pero si el usuario cambia a claro el fondo lo sigue.
picture-uri='file://${BG}/yaya-wallpaper-light.png'
picture-uri-dark='file://${BG}/yaya-wallpaper.png'
picture-options='zoom'
primary-color='#000000'
secondary-color='#000000'

[org/gnome/desktop/wm/preferences]
# Minimizar/maximizar visibles: el público de Yaya viene de Windows y
# GNOME por defecto sólo muestra "cerrar".
button-layout='appmenu:minimize,maximize,close'

[org/gnome/shell]
favorite-apps=[${FAVS}]
# Sin el diálogo "Te damos la bienvenida a GNOME" en el primer login.
welcome-dialog-last-shown-version='48.0'

[org/gnome/mutter]
# Escalado fraccional en Ajustes → Pantallas (portátiles HiDPI).
experimental-features=['scale-monitor-framebuffer']
edge-tiling=true
dynamic-workspaces=true

[org/gnome/nautilus/preferences]
default-folder-viewer='icon-view'

[org/gtk/settings/file-chooser]
sort-directories-first=true

[org/gtk/gtk4/settings/file-chooser]
sort-directories-first=true

[org/gnome/settings-daemon/plugins/power]
sleep-inactive-ac-type='nothing'
sleep-inactive-battery-type='suspend'
sleep-inactive-battery-timeout=1800

[org/gnome/software]
# Las actualizaciones de seguridad las hace unattended-upgrades;
# la tienda no debe descargar en segundo plano ni dar la lata.
download-updates=false
download-updates-notify=false
EOF

echo "==> [6/8] Pantalla de login (GDM): alien, oscuro, mismo cursor"
# GDM corre con su propio perfil dconf.
cat > /etc/dconf/profile/gdm <<'EOF'
user-db:user
system-db:gdm
EOF
cat > /etc/dconf/db/gdm.d/10-yaya-login <<EOF
# Yaya OS — marca del greeter. GDM escala el logo a 48 px de alto.
[org/gnome/login-screen]
logo='${BR}/yaya-logo-white.svg'
banner-message-enable=false
disable-user-list=false

[org/gnome/desktop/interface]
color-scheme='prefer-dark'
accent-color='teal'
cursor-theme='${CURSOR_THEME}'
cursor-size=24
EOF
dconf update

echo "==> [7/8] Apps no-GNOME: GTK y Qt siguen al escritorio"
# Sesiones/apps que no leen gsettings (GTK fuera de GNOME, LibreOffice, VLC).
install -d /etc/gtk-3.0 /etc/gtk-4.0
cat > /etc/gtk-3.0/settings.ini <<EOF
[Settings]
gtk-theme-name=Adwaita
gtk-icon-theme-name=Adwaita
gtk-cursor-theme-name=${CURSOR_THEME}
gtk-cursor-theme-size=24
gtk-application-prefer-dark-theme=1
gtk-font-name=Cantarell 11
EOF
cp /etc/gtk-3.0/settings.ini /etc/gtk-4.0/settings.ini
# Cursor por defecto de X/Xwayland: vía update-alternatives, que es quien
# gestiona /usr/share/icons/default/index.theme en Debian (no sobrescribirlo).
if [ "$CURSOR_THEME" != "Adwaita" ] && [ -f "/usr/share/icons/${CURSOR_THEME}/index.theme" ]; then
  update-alternatives --install /usr/share/icons/default/index.theme \
    x-cursor-theme "/usr/share/icons/${CURSOR_THEME}/index.theme" 100 >/dev/null
  update-alternatives --set x-cursor-theme \
    "/usr/share/icons/${CURSOR_THEME}/index.theme" >/dev/null
fi
# Qt (VLC, etc.) usa el tema GTK bajo GNOME.
grep -q '^QT_QPA_PLATFORMTHEME=' /etc/environment 2>/dev/null \
  || echo 'QT_QPA_PLATFORMTHEME=gnome' >> /etc/environment

# gnome-initial-setup: el usuario ya eligió idioma/teclado/cuenta en
# Calamares; no lo hagamos pasar por el asistente otra vez.
install -d /etc/skel/.config
echo yes > /etc/skel/.config/gnome-initial-setup-done

echo "==> [8/8] Limpieza"
install -d /usr/share/yaya/theme
cat > /usr/share/yaya/theme/gnome <<EOF
DESKTOP=gnome-core
DM=gdm3
CURSOR=${CURSOR_THEME}
FAVS=${FAVS}
WALLPAPER=${BG}/yaya-wallpaper.png
EOF
apt-get purge -y librsvg2-bin >/dev/null 2>&1 || true
apt-get autoremove -y >/dev/null 2>&1 || true

echo ""
echo "GNOME listo (Debian de fábrica, marca Yaya encima):"
sed 's/^/   /' /usr/share/yaya/theme/gnome
