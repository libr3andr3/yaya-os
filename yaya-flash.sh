#!/usr/bin/env bash
# ============================================================
# Yaya OS — build + flash a USB
#
#   sudo ./yaya-flash.sh                # construye ISO y flashea
#   sudo ./yaya-flash.sh --build-only   # solo construye la ISO
#   sudo ./yaya-flash.sh --flash-only yaya-os.iso   # solo flashea
#
# Requiere: Debian/Ubuntu host. Instala live-build si falta.
# ============================================================
set -euo pipefail

DISTRO_NAME="yaya-os"
DEBIAN_SUITE="trixie"          # Debian 13 (kernel 6.12 = mejor soporte de hardware)
BUILD_DIR="${BUILD_DIR:-$PWD/build-${DISTRO_NAME}}"
KIT_DIR="$(cd "$(dirname "$0")" && pwd)"
ISO_OUT="$PWD/${DISTRO_NAME}.iso"

MODE="all"
ISO_IN=""
case "${1:-}" in
  --build-only) MODE="build" ;;
  --flash-only) MODE="flash"; ISO_IN="${2:?Uso: --flash-only ruta.iso}" ;;
esac

[ "$(id -u)" -eq 0 ] || { echo "ERROR: ejecutar con sudo"; exit 1; }

# ------------------------------------------------------------
# Branding del gestor de arranque (menú isolinux + tema GRUB).
# Best-effort: si hay un renderer SVG->PNG en el host, dibuja el
# splash Yaya; si no, deja al menos los textos/labels de marca.
# ------------------------------------------------------------
brand_bootloaders() {
  # Splashes ya compuestos (fondo negro + lockup Yaya Tech centrado),
  # a tamaño exacto -> se rasterizan 1:1, sin distorsión.
  local svg_iso="$KIT_DIR/branding/yaya-boot-640x480.svg"
  local svg_grub="$KIT_DIR/branding/yaya-boot-1920x1080.svg"
  local renderer=""
  command -v rsvg-convert >/dev/null && renderer="rsvg"
  [ -z "$renderer" ] && command -v convert >/dev/null && renderer="im"
  if [ -z "$renderer" ]; then
    apt-get install -y --no-install-recommends librsvg2-bin >/dev/null 2>&1 \
      && command -v rsvg-convert >/dev/null && renderer="rsvg" || true
  fi
  if [ -z "$renderer" ]; then
    echo "   (sin renderer SVG en el host: el menú de arranque queda por"
    echo "    defecto; el splash de Plymouth se aplica igual en el chroot)"
    return 0
  fi

  # Solo reemplazamos el fondo (splash.png). NO tocamos menu.cfg/*.cfg:
  # live-build rellena el resto del tema isolinux/grub con sus defaults,
  # así que sobrescribir esos includes podría romper el arranque.
  mkdir -p config/bootloaders/isolinux config/bootloaders/grub-pc
  if [ "$renderer" = "rsvg" ]; then
    rsvg-convert -w 640  -h 480  "$svg_iso"  -o config/bootloaders/isolinux/splash.png
    rsvg-convert -w 1920 -h 1080 "$svg_grub" -o config/bootloaders/grub-pc/splash.png
  else
    convert -background black "$svg_iso"  config/bootloaders/isolinux/splash.png
    convert -background black "$svg_grub" config/bootloaders/grub-pc/splash.png
  fi
}

# ------------------------------------------------------------
# FASE 1 — CONSTRUIR ISO con live-build
# ------------------------------------------------------------
build_iso() {
  echo "=================================================="
  echo " Yaya OS — construyendo ISO (${DEBIAN_SUITE})"
  echo "=================================================="

  command -v lb >/dev/null || {
    echo "==> Instalando live-build"
    apt-get update && apt-get install -y live-build
  }

  # Conservar la caché apt/bootstrap entre builds (ahorra ~10 min y ~1.4 GB de red)
  [ -d "$BUILD_DIR/cache" ] && mv "$BUILD_DIR/cache" "${BUILD_DIR}.cache-keep"
  rm -rf "$BUILD_DIR"
  mkdir -p "$BUILD_DIR"
  [ -d "${BUILD_DIR}.cache-keep" ] && mv "${BUILD_DIR}.cache-keep" "$BUILD_DIR/cache"
  cd "$BUILD_DIR"

  echo "==> Configurando árbol live-build"
  # No debian-installer: la instalación la hace Calamares (GUI, interactiva).
  # Sesión live internacional por defecto (en_US/us); el sistema instalado
  # elige país/región/idioma/teclado dentro de Calamares.
  lb config \
    --distribution "$DEBIAN_SUITE" \
    --architectures amd64 \
    --binary-images iso-hybrid \
    --archive-areas "main contrib non-free non-free-firmware" \
    --debian-installer none \
    --bootappend-live "boot=live components splash quiet locales=en_US.UTF-8 keyboard-layouts=us username=live" \
    --iso-application "Yaya OS" \
    --iso-publisher "Yaya Tech PBC" \
    --iso-volume "YAYA_OS"

  echo "==> Lista de paquetes base"
  mkdir -p config/package-lists
  cat > config/package-lists/yaya.list.chroot <<'EOF'
firmware-linux-free
firmware-linux-nonfree
firmware-iwlwifi
firmware-realtek
network-manager
sudo
locales
bluez
bluez-firmware
EOF

  echo "==> Apps de escritorio (LibreOffice, VLC, impresión, tienda...)"
  cp "$KIT_DIR/yaya-desktop-apps.list" config/package-lists/yaya-desktop.list.chroot

  echo "==> Integrando hooks del kit (GNOME + branding + apps + Calamares)"
  mkdir -p config/hooks/live
  # Escritorio GNOME 48 + GDM con marca Yaya (reemplaza a Plasma/Cinnamon).
  cp "$KIT_DIR/setup-yaya-gnome.sh"     config/hooks/live/0500-yaya-gnome.hook.chroot
  # Wallets (Electrum/Feather -> nodos yaya.cash): DESACTIVADO hasta que la
  # infraestructura esté lista. Reactivar descomentando:
  # cp "$KIT_DIR/setup-yaya-wallets.sh"   config/hooks/live/0510-yaya-wallets.hook.chroot
  # Branding del sistema (os-release, plymouth, iconos). Corre antes de Calamares.
  cp "$KIT_DIR/setup-yaya-branding.sh"  config/hooks/live/0520-yaya-branding.hook.chroot
  # Táctil: sólo las piezas de hardware que GNOME necesita (iio-sensor-proxy)
  cp "$KIT_DIR/setup-yaya-touch.sh"     config/hooks/live/0530-yaya-touch.hook.chroot
  # Fastfetch con marca (alien en la terminal, config global, saludo)
  cp "$KIT_DIR/setup-yaya-fastfetch.sh"  config/hooks/live/0535-yaya-fastfetch.hook.chroot
  # Apps por defecto: Firefox ESR con uBlock Origin + handlers HTML/PDF
  cp "$KIT_DIR/setup-yaya-apps.sh"      config/hooks/live/0540-yaya-apps.hook.chroot
  # Post-config de apps de escritorio (Flathub, unattended-upgrades, CUPS)
  cp "$KIT_DIR/setup-yaya-desktop.sh"   config/hooks/live/0545-yaya-desktop.hook.chroot
  # Ajustes de sistema (dconf update, bluetooth, sudoers) — corre al final
  cp "$KIT_DIR/setup-yaya-system.sh"    config/hooks/live/0555-yaya-system.hook.chroot
  # Instalador gráfico Calamares — DE ÚLTIMO (necesita el resto ya instalado).
  cp "$KIT_DIR/calamares/setup-yaya-calamares.sh" config/hooks/live/0560-yaya-calamares.hook.chroot
  chmod +x config/hooks/live/*.hook.chroot

  echo "==> Copiando assets de marca al chroot (/usr/share/yaya/branding)"
  mkdir -p config/includes.chroot/usr/share/yaya/branding
  cp -r "$KIT_DIR/branding/." config/includes.chroot/usr/share/yaya/branding/
  mkdir -p config/includes.chroot/usr/share/yaya/fastfetch-src
  cp -r "$KIT_DIR/fastfetch/." config/includes.chroot/usr/share/yaya/fastfetch-src/
  cp "$KIT_DIR/yaya-webcam.sh" config/includes.chroot/usr/share/yaya/fastfetch-src/

  echo "==> Copiando kit Calamares al chroot (/usr/share/yaya/calamares)"
  mkdir -p config/includes.chroot/usr/share/yaya/calamares
  cp "$KIT_DIR/calamares/settings.conf" config/includes.chroot/usr/share/yaya/calamares/
  cp "$KIT_DIR/calamares/yaya-install"  config/includes.chroot/usr/share/yaya/calamares/
  cp -r "$KIT_DIR/calamares/modules"    config/includes.chroot/usr/share/yaya/calamares/
  cp -r "$KIT_DIR/calamares/branding"   config/includes.chroot/usr/share/yaya/calamares/

  echo "==> Branding del menú de arranque (isolinux + GRUB)"
  brand_bootloaders

  echo "==> Construyendo (esto toma 20-60 min según red/CPU)..."
  lb build 2>&1 | tee build.log

  ISO_BUILT=$(ls -1 live-image-*.hybrid.iso 2>/dev/null | head -n1)
  [ -n "$ISO_BUILT" ] || { echo "ERROR: no se generó la ISO. Revisa build.log"; exit 1; }
  mv "$ISO_BUILT" "$ISO_OUT"
  echo ""
  echo "==> ISO lista: $ISO_OUT ($(du -h "$ISO_OUT" | cut -f1))"
  sha256sum "$ISO_OUT" | tee "${ISO_OUT}.sha256"
}

# ------------------------------------------------------------
# FASE 2 — FLASHEAR a USB (con protecciones)
# ------------------------------------------------------------
flash_usb() {
  local iso="$1"
  [ -f "$iso" ] || { echo "ERROR: no existe $iso"; exit 1; }

  echo ""
  echo "=================================================="
  echo " Dispositivos USB extraíbles detectados:"
  echo "=================================================="
  # Solo discos extraíbles (RM=1), nunca el disco del sistema
  lsblk -d -o NAME,SIZE,MODEL,TRAN,RM | awk 'NR==1 || $NF==1'
  echo ""

  # Detectar el disco donde vive la raíz para bloquearlo
  ROOT_DISK=$(lsblk -no PKNAME "$(findmnt -no SOURCE /)" 2>/dev/null | head -n1 || true)

  read -rp "Escribe el dispositivo destino (ej: sdb — se BORRARÁ TODO): " DEV
  DEV="/dev/${DEV#/dev/}"

  # --- Protecciones ---
  [ -b "$DEV" ] || { echo "ERROR: $DEV no es un dispositivo de bloque"; exit 1; }
  [ "$(lsblk -dno RM "$DEV")" = "1" ] || {
    echo "ERROR: $DEV no es extraíble. Abortando por seguridad."; exit 1; }
  [ "$(basename "$DEV")" != "$ROOT_DISK" ] || {
    echo "ERROR: $DEV es el disco del sistema. Abortando."; exit 1; }

  ISO_SIZE=$(stat -c%s "$iso")
  DEV_SIZE=$(blockdev --getsize64 "$DEV")
  [ "$DEV_SIZE" -ge "$ISO_SIZE" ] || {
    echo "ERROR: el USB ($(numfmt --to=iec "$DEV_SIZE")) es menor que la ISO ($(numfmt --to=iec "$ISO_SIZE"))"; exit 1; }

  echo ""
  echo "  ISO    : $iso ($(numfmt --to=iec "$ISO_SIZE"))"
  echo "  Destino: $DEV ($(lsblk -dno MODEL "$DEV" | xargs), $(numfmt --to=iec "$DEV_SIZE"))"
  echo ""
  read -rp "TODO el contenido de $DEV se destruirá. Escribe 'SI' para continuar: " CONFIRM
  [ "$CONFIRM" = "SI" ] || { echo "Cancelado."; exit 0; }

  echo "==> Desmontando particiones de $DEV"
  umount "${DEV}"?* 2>/dev/null || true

  echo "==> Escribiendo ISO..."
  dd if="$iso" of="$DEV" bs=4M status=progress conv=fsync oflag=direct
  sync

  echo "==> Verificando (sha256 de los primeros $(numfmt --to=iec "$ISO_SIZE"))"
  ISO_HASH=$(sha256sum "$iso" | cut -d' ' -f1)
  DEV_HASH=$(head -c "$ISO_SIZE" "$DEV" | sha256sum | cut -d' ' -f1)
  if [ "$ISO_HASH" = "$DEV_HASH" ]; then
    echo "✔ Verificación OK — el USB es idéntico a la ISO."
  else
    echo "✘ ERROR: la verificación falló. USB posiblemente defectuoso."; exit 1;
  fi


  echo "==> Creando partición de PERSISTENCIA en el espacio restante del USB"
  # La ISO isohybrid usa particiones 1 (iso) y 2 (EFI); añadimos la 3
  if printf 'n\np\n3\n\n\nw\n' | fdisk "$DEV" >/dev/null 2>&1; then
    partprobe "$DEV" 2>/dev/null || true; sleep 2
    PERS="${DEV}3"
    if [ -b "$PERS" ]; then
      mkfs.ext4 -q -F -L persistence "$PERS"
      MNT=$(mktemp -d)
      mount "$PERS" "$MNT"
      echo "/ union" > "$MNT/persistence.conf"
      umount "$MNT"; rmdir "$MNT"
      echo "✔ Persistencia lista ($PERS, label=persistence)."
      echo "  Usa la entrada 'Live persistente' del menú de arranque."
    else
      echo "AVISO: no apareció $PERS; persistencia omitida."
    fi
  else
    echo "AVISO: fdisk no pudo crear la partición 3; persistencia omitida."
  fi

  eject "$DEV" 2>/dev/null || true
  echo ""
  echo "=================================================="
  echo " Listo. USB booteable de Yaya OS: $DEV"
  echo " Bootea con UEFI o BIOS legacy (iso-hybrid)."
  echo "=================================================="
}

# ------------------------------------------------------------
case "$MODE" in
  build) build_iso ;;
  flash) flash_usb "$ISO_IN" ;;
  all)   build_iso; flash_usb "$ISO_OUT" ;;
esac
