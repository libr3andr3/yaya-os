# Yaya OS

> **2026-08-25:** escritorio = **GNOME 48 (Wayland) + GDM**
> (`setup-yaya-gnome.sh`). Plasma/Cinnamon/XFCE quedan como referencia histórica.
>
> El escritorio es el **GNOME de Debian sin parchar** — el mismo que sale de un
> install por defecto de Debian 13 — y la marca Yaya se aplica sólo por los
> caminos que GNOME soporta: `dconf` (base de sistema), logo de GDM, wallpaper
> propio y tema de cursor. Nada de parchar gresources ni temas de shell: eso se
> rompe en cada actualización. Apps GNOME (Files, Console, Software, Settings,
> visor de documentos/fotos…) + LibreOffice, Firefox+uBlock, VLC, Thunderbird,
> CUPS. `fastfetch` se ejecuta sólo al escribirlo y renderiza el alien al tamaño
> de la terminal.

Pensado para hardware refurbished y para construirse como ISO Debian con
`live-build` (`yaya-flash.sh`).

## Contenido

```
setup-yaya-gnome.sh          # ESCRITORIO: GNOME 48 + GDM + marca Yaya
setup-yaya-branding.sh       # BRANDING DE ARRANQUE: os-release, hostname,
                             #   splash Plymouth (lockup + barra), logo del SO
setup-yaya-touch.sh          # táctil: sólo las piezas que GNOME necesita
setup-yaya-apps.sh           # Firefox ESR + uBlock, handlers HTML/PDF
setup-yaya-desktop.sh        # Flathub, unattended-upgrades, CUPS
setup-yaya-wallets.sh        # Electrum (BTC) + Feather (XMR) -> nodos yaya.cash
setup-yaya-fastfetch.sh      # fastfetch con marca Yaya: alien en la terminal,
                             #   config global + saludo al abrir terminal
yaya-webcam.sh               # puente DSLR -> /dev/video42 con banner Yaya
yaya-flash.sh                # construye la ISO (live-build) y la flashea a USB
calamares/                   # instalador gráfico (settings, módulos, branding)
fastfetch/                   # assets de terminal
  config.jsonc               #   default del sistema (-> /etc/fastfetch)
  webcam.jsonc / -compact    #   banner del dashboard de yaya-webcam
  yaya-logo*.txt             #   alien ASCII fijo (fallback)
  yaya-logo-gen.py           #   re-renderiza el alien al tamaño de terminal
branding/                    # marca REAL vectorizada (Yaya Tech), SVG puro
  yaya-logo.svg              #   alien solo (logo del SO, logo de GDM)
  yaya-logo-full.svg         #   lockup alien + "Yaya Tech" (transparente)
  yaya-boot-1920x1080.svg    #   splash de arranque GRUB (negro + lockup)
  yaya-boot-640x480.svg      #   splash de arranque isolinux
  yaya-wallpaper.svg         #   fondo de escritorio 4K (alien sobre negro)
  yaya-wallpaper-light.svg   #   ídem, para el modo claro de GNOME
tools/
  make-wallpaper.py          # recompone los wallpapers desde el alien
--- histórico (no se construye) ---
setup-yaya-plasma.sh         # KDE Plasma 6 + SDDM + Fluent Round
setup-yaya-win10.sh          # apariencia Win10 sobre XFCE
setup-yaya-cinnamon.sh       # Cinnamon
skel/.config/xfce4/          # panel/atajos estilo Win10 para XFCE
```

## Escritorio GNOME (setup-yaya-gnome.sh)

Hook `0500`. La regla es **no pelearse con GNOME**: se instala `gnome-core`
(el GNOME oficial de Debian, el mismo de un install por defecto) y la marca
va encima por los cuatro caminos soportados.

| Qué | Cómo | Dónde |
|---|---|---|
| Tema oscuro + acento teal | `dconf` system db | `/etc/dconf/db/local.d/00-yaya-desktop` |
| Wallpaper del alien | PNG 4K + `gnome-background-properties` | `/usr/share/backgrounds/yaya/` |
| Logo del login | `org.gnome.login-screen logo` | `/etc/dconf/db/gdm.d/10-yaya-login` |
| Cursor | Bibata Modern Ice + `update-alternatives` | `/usr/share/icons/` |

Todo son **defaults, no locks**: el usuario puede cambiar cualquier cosa en
Ajustes y su elección gana. No se parchea ningún `gresource` ni tema de
GNOME Shell — eso es exactamente lo que se rompe en cada actualización.

Otros toques: botones minimizar/maximizar visibles (el público de Yaya viene
de Windows y GNOME sólo muestra "cerrar"), escalado fraccional habilitado,
dash con Firefox/Files/Console/Software/Ajustes, sin diálogo de bienvenida
de GNOME ni `gnome-initial-setup` (el usuario ya eligió idioma, teclado y
cuenta en Calamares), y GNOME Software sin descargas en segundo plano
(de la seguridad se encarga `unattended-upgrades`).

### Cursor: por qué Bibata Modern Ice

Se revisaron los sets que hoy se recomiendan para GNOME/Wayland —
**Bibata**, **Capitaine**, **Phinger**, **Adwaita** (el de fábrica) y
**WhiteSur**. Bibata Modern Ice gana para este caso:

- Blanco con contorno negro y bordes redondeados: pega con el alien plata
  sobre negro y se ve sobre cualquier wallpaper.
- Vectorial y con tamaños hasta 4K — importante en la flota mixta de
  paneles viejos y portátiles HiDPI.
- **GPL-3.0**, o sea redistribuible en una ISO comercial (ver *Licencias*).

Se instala desde el release pinneado `v2.0.7` de GitHub; si la descarga
falla, el build **no** se cae: se queda el cursor Adwaita de GNOME.

## Branding de arranque (setup-yaya-branding.sh)

El logo real de **Yaya Tech** (alien con seña de paz) fue vectorizado del
PNG original a SVG puro con VTracer — incluido el texto "Yaya Tech", que
son **trazos vectoriales, no `<text>`**: nítido a cualquier resolución y
sin depender de ninguna fuente. Aplica:

- **Identidad del sistema**: `/etc/os-release` (`LOGO=yaya-logo`),
  `/etc/lsb-release`, `hostname=yaya`, `/etc/issue`, `/etc/motd`.
- **Splash de arranque**: tema Plymouth `yaya` — el lockup completo
  (alien + "Yaya Tech") **centrado** sobre negro, escalado al tamaño de
  pantalla en tiempo de arranque (nítido en cualquier resolución), con una
  **barra de progreso** debajo alimentada por el progreso real del arranque
  (misma composición que tenía el splash de Plasma).
- **Logo del SO = solo el alien**: se instala como icono `distributor-logo`
  / `start-here`; GNOME lo muestra en Ajustes → Acerca de vía `LOGO=` de
  `/etc/os-release`.
- **Menú de arranque** (isolinux/GRUB): mismo lockup sobre negro
  (lo pone `yaya-flash.sh`).

**No toca el escritorio**: no cambia wallpaper, tema ni greeter — de eso se
ocupa `setup-yaya-gnome.sh`. Aquí sólo el arranque y la identidad. Los SVG se
rasterizan en el chroot con `rsvg-convert` (instalado y purgado por el
propio hook). Corre como hook `0520`.

### Regenerar los SVG desde el PNG original

Los assets de `branding/` ya están vectorizados y versionados. Si cambia
el logo original, se re-vectoriza con VTracer (ver el PNG fuente en
`~/Downloads/yayatech.png`). No hace falta para construir la ISO.

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

Hook live-build: `config/hooks/live/0535-yaya-fastfetch.hook.chroot`.

## Táctil / pantallas táctiles

Ver **[TOUCHSCREEN.md](TOUCHSCREEN.md)**. Resumen: **lo maneja GNOME**.
Teclado en pantalla que aparece y desaparece solo, gestos, auto-rotación,
modo tablet y stylus vienen de fábrica en GNOME 48 sobre Wayland.
`setup-yaya-touch.sh` sólo instala `iio-sensor-proxy` (el acelerómetro) y
deja unos defaults de touchpad en `dconf` — cero hacks.

## Construir la ISO

```bash
sudo ./yaya-flash.sh --build-only     # sólo la ISO
sudo ./yaya-flash.sh                  # ISO + flashear a un USB
```

`yaya-flash.sh` arma el árbol de `live-build`, cablea cada `setup-yaya-*.sh`
como hook numerado (`0500` GNOME → `0560` Calamares) y copia los assets de
`branding/` al chroot.

## Aplicar a una máquina ya instalada

Los hooks también corren sueltos sobre un Debian 13 normal:

```bash
sudo ./setup-yaya-gnome.sh      # escritorio + marca
sudo ./setup-yaya-branding.sh   # identidad + splash de arranque
sudo ./setup-yaya-touch.sh      # acelerómetro + defaults de touchpad
# cerrar sesión y volver a entrar
```

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

## Licencias — importante para distribución comercial

- Cursor: `ful1e5/Bibata_Cursor` (Bibata Modern Ice) — GPL-3.0 ✔ redistribuible
- Escritorio, iconos y tipografía: GNOME/Adwaita + Cantarell, tal como los
  empaqueta Debian ✔ redistribuible
- Marca Yaya (`branding/`, wallpapers): propiedad de Yaya Tech PBC
- NO incluir: Segoe UI, wallpapers de Microsoft, logo de Windows (aplicaba
  al kit XFCE histórico, ver abajo).
- Verifica cada asset adicional que agregues antes de meterlo a la ISO.

## (histórico) Kit XFCE "Windows 10"

`setup-yaya-win10.sh`, `setup-yaya-cinnamon.sh`, `setup-yaya-plasma.sh` y
`skel/.config/xfce4/` son las etapas anteriores del proyecto (XFCE con
apariencia Win10 → Cinnamon → KDE Plasma 6). Se conservan como referencia;
**ninguno se construye**. El tema y los iconos "Windows-10" de B00merang que
usaba el kit XFCE son GPL y eran redistribuibles, pero ya no se incluyen en
la ISO.
