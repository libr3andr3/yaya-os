#!/usr/bin/env bash
# ============================================================
#   curl yaya.sh | bash   —   instalador de Yaya OS
#
# Descarga la ISO de Yaya OS, VERIFICA su firma GPG contra la
# clave de release (fingerprint pineado abajo) y la graba en un
# USB. Luego arrancas el USB y el instalador hace el resto.
# ============================================================
set -euo pipefail

BASE="${YAYA_BASE:-https://yaya.sh}"
ISO_URL="$BASE/yaya-os.iso"
SIG_URL="$BASE/yaya-os.iso.asc"
KEY_URL="$BASE/yaya-release.pub.asc"
# Clave de firma de Yaya OS (releases@yaya.sh) — PINEADA:
FPR="0599115B6BAE51AB1CA37BD819EF40CA504239C8"

mag(){ printf "\033[1;35m%s\033[0m\n" "$*"; }   # magenta (el vibe Yaya)
ok(){ printf "  \033[32m✔\033[0m %s\n" "$*"; }
err(){ printf "  \033[31m✘ %s\033[0m\n" "$*" >&2; }
ask(){ local p="$1" v; read -r -p "$p" v < /dev/tty; printf '%s' "$v"; }

trap 'rm -rf "${TMP:-}"' EXIT
TMP="$(mktemp -d)"

mag "=================================================="
mag "   Yaya OS  —  soberanía digital, hardware honesto"
mag "=================================================="
echo

for tool in curl gpg lsblk dd sha256sum; do
  command -v "$tool" >/dev/null || { err "falta '$tool' (instálalo y reintenta)"; exit 1; }
done

echo "==> Descargando clave de firma y verificando huella…"
curl -fsSL "$KEY_URL" -o "$TMP/key.asc" || { err "no pude bajar la clave"; exit 1; }
export GNUPGHOME="$TMP/gnupg"; mkdir -p "$GNUPGHOME"; chmod 700 "$GNUPGHOME"
gpg --quiet --import "$TMP/key.asc" 2>/dev/null
GOT="$(gpg --with-colons --fingerprint releases@yaya.sh 2>/dev/null | awk -F: '/^fpr:/{print $10; exit}')"
if [ "$GOT" != "$FPR" ]; then
  err "la huella de la clave NO coincide con la esperada — ABORTO."
  err "esperada: $FPR"; err "recibida: ${GOT:-<ninguna>}"; exit 1
fi
ok "clave de release verificada ($FPR)"

echo "==> Descargando ISO (~1.8 GB) y su firma…"
curl -fL# "$ISO_URL" -o "$TMP/yaya-os.iso"
curl -fsSL "$SIG_URL" -o "$TMP/yaya-os.iso.asc" || { err "no pude bajar la firma"; exit 1; }

echo "==> Verificando la firma de la ISO…"
if gpg --quiet --verify "$TMP/yaya-os.iso.asc" "$TMP/yaya-os.iso" 2>/dev/null; then
  ok "firma VÁLIDA — la ISO es auténtica de Yaya OS"
else
  err "FIRMA INVÁLIDA — la ISO puede estar corrupta o manipulada. ABORTO."; exit 1
fi

echo
echo "==> Discos USB extraíbles detectados:"
lsblk -dn -o NAME,SIZE,MODEL,TRAN,RM | awk '$4=="usb" && $5==1 {printf "     /dev/%s  %s  %s\n",$1,$2,$3}'
echo
DEV="$(ask 'Escribe el dispositivo destino (ej: sdb) — se BORRARÁ TODO: ')"
DEV="/dev/${DEV#/dev/}"
[ -b "$DEV" ] || { err "$DEV no es un dispositivo de bloque"; exit 1; }
[ "$(lsblk -dno RM "$DEV")" = "1" ] || { err "$DEV no es extraíble. Aborto por seguridad."; exit 1; }
ROOT_DISK="$(lsblk -no PKNAME "$(findmnt -no SOURCE /)" 2>/dev/null | head -n1 || true)"
[ "$(basename "$DEV")" != "$ROOT_DISK" ] || { err "$DEV es el disco del sistema. Aborto."; exit 1; }

echo
CONF="$(ask "TODO en $DEV se destruirá. Escribe 'SI' para grabar: ")"
[ "$CONF" = "SI" ] || { echo "Cancelado."; exit 0; }

echo "==> Grabando (sudo)…"
sudo umount "${DEV}"?* 2>/dev/null || true
sudo dd if="$TMP/yaya-os.iso" of="$DEV" bs=4M status=progress conv=fsync oflag=direct
sync
ISZ="$(stat -c%s "$TMP/yaya-os.iso")"
if [ "$(sha256sum "$TMP/yaya-os.iso" | cut -d' ' -f1)" = "$(sudo head -c "$ISZ" "$DEV" | sha256sum | cut -d' ' -f1)" ]; then
  ok "USB verificado — idéntico a la ISO"
else
  err "la verificación de escritura falló (USB defectuoso?)"; exit 1
fi
sudo eject "$DEV" 2>/dev/null || true

echo
mag "Listo. Arranca desde $DEV y elige «Instalar Yaya OS»."
mag "Instalación guiada: disco completo, cifrado. Bienvenido a Yaya. ☮"
