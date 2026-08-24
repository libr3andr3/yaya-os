# Bootstrap de una máquina nueva con Yaya OS

Checklist para incorporar una instalación fresca de Yaya OS a la flota
(caso de referencia: ThinkPad nuevo, 2026-08-23).

## 1. Acceso remoto (primer paso, en la máquina nueva)

La imagen de Yaya OS **no** trae sshd. En la máquina nueva:

```bash
sudo apt install -y openssh-server
sudo systemctl enable --now ssh
```

Desde la workstation, autorizar la llave:

```bash
ssh-copy-id -i ~/.ssh/id_ed25519.pub <usuario>@<ip-lan>
```

## 2. Identidad y accesos (copiar desde la workstation)

Solo lo mínimo — llave de GitHub, aliases y llaves SSH:

- `~/.ssh/id_ed25519` + `.pub` (GitHub / nodos)
- `~/.ssh/sigma` + `.pub` (node.agente.ceo / .fit)
- `~/.ssh/config` (aliases: node.yaya.tech, node.lan, vps, node.agente.*)
- Permisos: `chmod 700 ~/.ssh && chmod 600 ~/.ssh/*` (`.pub` en 644)

## 3. Kit homelab esencial

```bash
sudo apt install -y \
  htop tmux rsync jq ncdu tree lsof \
  dnsutils mosh iperf3 ethtool nmap \
  usbutils pciutils wireguard-tools avahi-daemon
```

Contenedores: **podman** (sin demonio, rootless, más liviano que Docker
para hardware modesto) + alias de compatibilidad:

```bash
sudo apt install -y podman podman-compose
```

`podman` corre contra el kernel del host directamente (no hay VM ni
passthrough que configurar — Yaya OS *es* Debian); las apps localhost
(puertos, volúmenes) funcionan igual que con Docker.

## 4. Git soberano — libre.yaya.tech

Forge propio (Forgejo) en node.yaya.tech, público en **https://libre.yaya.tech**
(docker `forgejo`, web en 127.0.0.1:3300 detrás de Caddy; SNI exacto en el
VPS → 10.0.0.5). Registro deshabilitado; credenciales admin en
`node:~/forgejo/ADMIN-CREDENTIALS.txt`.

- Clonar (público, https): `git clone https://libre.yaya.tech/yaya/yaya-os.git`
- Push desde la workstation: remoto `sovereign` con doble pushurl —
  el bare `node.yaya.tech:git/yaya-os.git` **y** el forge por https
  (token en `~/.git-credentials`). Un solo `git push sovereign` actualiza ambos.
- Repo bare de respaldo en `node:~/git/yaya-os.git`; crear repos nuevos:
  por la UI/API de Forgejo, o `ssh node.yaya.tech 'git init --bare ~/git/<nombre>.git'`

## 5. Pendientes por máquina

- Unir al mesh WireGuard del vps (siguiente IP libre 10.0.0.x) para
  alcanzarla fuera de la LAN.
- Aplicar fixes de hardware específicos (ej. bluetooth — ver
  `fixes/`) y subirlos a este repo para que la próxima ISO los incluya.
