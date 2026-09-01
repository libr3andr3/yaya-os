# Yaya OS

ISO Debian (trixie) live + instalable para hardware refurbished: escritorio
**KDE Plasma 6 (Wayland) + SDDM**, instalador gráfico **Calamares**, identidad
de marca **Yaya Tech** completa (splash de arranque, greeter, os-release,
terminal). Se construye con `live-build` vía `yaya-flash.sh`.

> **2026-09-01:** vuelta a **KDE Plasma 6 + SDDM + Fluent Round**
> (`setup-yaya-plasma.sh`), conservando lo bueno de la era GNOME: codecs HW
> (VA-API), HEIC/WebP, firmware SOF/microcode, Epson/Brother, udisks2, 7z/rar,
> y el splash de Plymouth con el **alien centrado** sobre negro.
>
> Historial de escritorios: XFCE/Win10 → Cinnamon → KDE Plasma 6 → GNOME →
> KDE Plasma 6. Los kits anteriores (win10/skel XFCE, cinnamon, gnome, preseed
> d-i) viven en el historial de git; el árbol solo lleva lo que se construye hoy.

## Contenido

```
yaya-flash.sh                # build de la ISO (live-build) + flasheo a USB
web-install.sh               # curl yaya.tech | bash — baja ISO firmada y flashea
setup-yaya-plasma.sh         # hook 0500: Plasma 6 + SDDM + Fluent Round, alien en el panel
setup-yaya-wallets.sh        # hook 0510 (DESACTIVADO): Electrum/Feather -> yaya.cash
setup-yaya-branding.sh       # hook 0520: os-release, Plymouth (alien), iconos
setup-yaya-touch.sh          # hook 0530: táctil (auto-rotación, OSK, gestos)
setup-yaya-fastfetch.sh      # hook 0535: fastfetch con marca (alien en terminal)
setup-yaya-apps.sh           # hook 0540: Xournal++, Firefox ESR + uBlock
setup-yaya-desktop.sh        # hook 0545: Flathub, unattended-upgrades, CUPS
setup-yaya-system.sh         # hook 0555: bluetooth, sudoers, limpieza
calamares/                   # hook 0560: instalador gráfico (ver su README)
yaya-desktop-apps.list       # apps "daily driver" (LibreOffice, VLC, Thunderbird…)
branding/                    # marca vectorizada (SVG puro, sin fuentes)
  yaya-logo.svg              #   alien solo (logo del SO y splash de Plymouth)
  yaya-logo-full.svg         #   lockup alien + "Yaya Tech"
  yaya-boot-1920x1080.svg    #   splash del menú GRUB
  yaya-boot-640x480.svg      #   splash del menú isolinux
fastfetch/                   # assets de terminal (config, alien ASCII, generador)
yaya-webcam.sh               # puente DSLR -> /dev/video42 con banner Yaya
web/os/                      # página de descarga yaya.tech/os
docs/                        # visión, bootstrap de máquinas nuevas, screenshots
```

## Escritorio (setup-yaya-plasma.sh)

KDE Plasma 6 en Wayland con SDDM, sin autologin (usuario recordado en el
login). Tema global **Fluent Round dark** (vinceliuice): Plasma, ventanas
(Aurorae), Kvantum, iconos Fluent, GTK Fluent y SDDM Fluent, con el alien
blanco como botón de inicio (Kickoff), en el splash de Plasma y en el
greeter. Panel auto-hide, reloj y show-desktop estándar, touchpad con
scroll natural + tap-to-click (`/etc/xdg/kcminputrc`), KWallet apagado,
Discover sin notificaciones agresivas de updates (unattended-upgrades ya
cubre seguridad).

`branding/yaya-beach.jpg` (Pexels 457882, licencia Pexels libre de
regalías) queda en el kit por si se quiere como wallpaper por defecto.

## Branding de arranque (setup-yaya-branding.sh)

El logo real de **Yaya Tech** (alien con seña de paz) fue vectorizado del
PNG original a SVG puro con VTracer — trazos vectoriales, no `<text>`:
nítido a cualquier resolución y sin depender de ninguna fuente. Aplica:

- **Identidad del sistema**: `/etc/os-release` (`LOGO=yaya-logo`),
  `/etc/lsb-release`, `hostname=yaya`, `/etc/issue`, `/etc/motd`.
- **Splash de arranque**: tema Plymouth `yaya` — el **alien centrado**
  sobre negro (~26% del lado menor de la pantalla), con puntos de progreso
  y prompt de LUKS debajo.
- **Logo del SO = solo el alien**: instalado como icono `distributor-logo`
  / `start-here` (aparece en Ajustes → Acerca de).
- **Menú de arranque** (isolinux/GRUB): lockup sobre negro (lo pone
  `yaya-flash.sh`).

Los SVG se rasterizan en el chroot con `rsvg-convert` (instalado y purgado
por el propio hook).

## Fastfetch con marca (setup-yaya-fastfetch.sh)

La "cara" de Yaya OS en la terminal: `fastfetch` muestra el alien en ASCII
junto a la info del sistema, en el verde-teal de la marca (`38;5;79`).

- **Config global**: `/etc/fastfetch/config.jsonc` — aplica a todos los
  usuarios; cualquiera la pisa con `~/.config/fastfetch/config.jsonc`.
- **Logo vivo**: `yaya-logo-gen.py` re-renderiza el alien desde
  `branding/yaya-logo.png` al tamaño exacto que se le pida (Pillow,
  resample BOX + rampa de densidad). Los `.txt` fijos son el fallback
  cuando no hay Pillow.
- **Saludo**: las terminales nuevas abren con el banner (snippet en
  `/etc/skel/.bashrc`, una vez por sesión vía `YAYA_FF_GREETED`).
- **yaya-webcam**: puente DSLR → `/dev/video42` (gphoto2 + ffmpeg +
  v4l2loopback) con el banner centrado en tmux y el contador de frames de
  ffmpeg en la barra de estado. Los deps de streaming no van en la ISO
  base; el script indica cómo instalarlos si faltan.

## Construir la ISO

```bash
sudo ./yaya-flash.sh                # construye ISO y flashea a USB
sudo ./yaya-flash.sh --build-only   # solo construye
sudo ./yaya-flash.sh --flash-only yaya-os.iso
```

Host Debian/Ubuntu; instala `live-build` si falta. El script arma el árbol
de live-build desde cero en cada build (los hooks se copian del kit, la
caché apt se conserva) y al flashear añade una partición de persistencia
en el espacio libre del USB.

## Wallets (setup-yaya-wallets.sh) — NO incluido en la ISO por ahora

> Desactivado en `yaya-flash.sh` (2026-08-22) hasta que los nodos de yaya.cash
> estén listos. El hook sigue en el repo; reactivar descomentando la línea `0510`.

Bitcoin y Monero preinstalados, apuntando a infraestructura Yaya por defecto:

| Moneda | Wallet | Nodo default | Por qué |
|---|---|---|---|
| BTC | Electrum | `electrum.yaya.cash:50002` (SSL) | estándar, liviano, servidor propio |
| XMR | Feather | `node.yaya.cash:18089` | ligero, Tor integrado, ideal HW modesto |

Ambas descargas se **verifican con GPG** contra las llaves de los
mantenedores y las versiones están pinneadas — actualiza deliberadamente.

### Lo que yaya.cash debe correr (lado servidor)

```
BTC:  bitcoind (full node) + Fulcrum o electrs  -> puerto 50002 SSL
XMR:  monerod con --restricted-rpc --rpc-bind-port 18089 --public-node
      (RPC restringido: nunca exponer 18081 sin restricted)
```

### Modelo de confianza (documentar al usuario)

Usar el nodo comunitario = el nodo ve tu IP y (en BTC) tus direcciones.
Es el trade-off custodial-by-default. Ambas wallets permiten cambiar a
nodo propio en Configuración — ese es el camino sovereign-by-choice.
Considera ofrecer el nodo también como hidden service (.onion): Feather
lo soporta nativo por Tor.
