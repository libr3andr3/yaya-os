# Visión — red de comunicaciones descentralizada Yaya OS

*(futuro — anotado 2026-08-23; no es trabajo en curso)*

Cada instalación de Yaya OS puede correr apps livianas en localhost y
unirse a una red de comunicaciones propia:

- **Agento localhost**: port del core sovereign de Agento (SQLite +
  gateway llm.yaya.tech) corriendo como servicio local en cada máquina,
  aun en hardware modesto — por eso podman/containers livianos.
- **Canales**:
  - WhatsApp vía la librería Rust (whatsapp-rust) — mensajería.
  - Llamadas por WhatsApp (proyecto whatsapp caller de GitHub).
  - Matrix — servidor/es propios como transporte federado entre nodos.
- **Red**: cada instalador de Yaya OS se une a la red (mesh WireGuard +
  federación Matrix) — comunicaciones soberanas entre todos los nodos,
  sin depender de infraestructura ajena.
- **Git soberano** (ya iniciado): repos bare en node.yaya.tech; opción
  futura de Forgejo con UI web en git.yaya.tech si hace falta.

Primer paso concreto ya hecho: bootstrap documentado en
`NEW-MACHINE.md` y remoto git soberano activo.
