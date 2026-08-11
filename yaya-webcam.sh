#!/bin/bash
#
# Yaya OS: DSLR -> /dev/video42 webcam bridge, with the Yaya banner.
# Installed as /usr/bin/yaya-webcam by setup-yaya-fastfetch.sh.
#
#   yaya-webcam          Renders a tmux session: the fastfetch banner
#                        centered in the window, and the live ffmpeg
#                        frame counter updating on the bottom (status)
#                        line. Falls back to the plain banner+stream if
#                        tmux isn't installed.
#   yaya-webcam --plain  Just the stream, no banner, no tmux.
#
set -uo pipefail

# Assets live in /usr/share/yaya/fastfetch (installed by
# setup-yaya-fastfetch.sh); set YAYA_FF_DIR to point elsewhere for development.
CFG_DIR="${YAYA_FF_DIR:-/usr/share/yaya/fastfetch}"
FF_FULL="$CFG_DIR/webcam.jsonc"
FF_MIN="$CFG_DIR/webcam-compact.jsonc"
LOGO_BIG="$CFG_DIR/yaya-logo.txt"
LOGO_SMALL="$CFG_DIR/yaya-logo-small.txt"
LOGO_GEN="$CFG_DIR/yaya-logo-gen.py"
RUNDIR="${XDG_RUNTIME_DIR:-/tmp}"
LOG="$RUNDIR/yaya-webcam.log"

# gphoto2 enumerates every PTP device it can see — a plugged-in Android phone
# included, and it will happily pick that one first. Match the model explicitly.
# Override for a different body:  YAYA_CAM_MATCH='Nikon' ./start_webcam.sh
CAM_MATCH="${YAYA_CAM_MATCH:-Canon}"
export YAYA_CAM_MATCH="$CAM_MATCH"   # the fastfetch camera module reads this too

# Echo "<usb:bus,dev>\t<model>" for the first detected camera matching CAM_MATCH.
detect_camera() {
    gphoto2 --auto-detect 2>/dev/null | awk -v pat="$CAM_MATCH" '
        NR > 2 && $0 ~ pat {
            if (match($0, /usb:[0-9]+,[0-9]+/)) {
                port = substr($0, RSTART, RLENGTH)
                model = substr($0, 1, RSTART - 1)
                sub(/[ \t]+$/, "", model)
                print port "\t" model
                exit
            }
        }'
}

# ------------------------------------------------------------------ layout ---
# The logo is not a fixed-size .txt any more: yaya-logo-gen.py re-renders the
# alien mark from the source PNG at whatever cell size we ask for, so the banner
# fills the terminal's full height. The two shipped .txt logos stay as the
# fallback for when python3/Pillow or the PNG isn't there.
#
# Dimensions of the info column (no logo) for each config, measured with
#   fastfetch --config <cfg> --logo none | sed 's/\x1b\[[0-9;]*m//g'
# They depend on how long this machine's CPU/GPU strings are, so re-measure if
# you ever move these configs to a box with a chattier CPU model name.
FULL_INFO_W=53; FULL_INFO_H=14; FULL_LOGO_PAD_TOP=1   # webcam.jsonc
MIN_INFO_W=36;  MIN_INFO_H=9;   MIN_LOGO_PAD_TOP=0    # webcam-compact.jsonc
LOGO_MARGIN=4        # the configs' logo padding: left 1 + right 3
LOGO_MIN_W=12        # below this the mark is mush — drop it instead

# Pick the banner variant for <cols>x<rows>, sizing the logo to the rows left
# over after <reserve> lines (0 when the banner owns the whole screen).
#
# The mark keeps its aspect ratio, so on a narrowish terminal the info column is
# what stops it reaching the bottom of the screen. When that happens the compact
# column — 17 columns narrower — is tried too, and wins if it buys the mark real
# height; the full column is kept whenever it costs the logo nothing.
pick_layout() {
    local cols="$1" rows="$2" reserve="${3:-0}" full_h=-1
    if [ "$cols" -ge 90 ] && [ "$rows" -ge $(( FULL_INFO_H + 2 + reserve )) ]; then
        fit_layout "$FF_FULL" "$FULL_INFO_W" "$FULL_INFO_H" "$FULL_LOGO_PAD_TOP" "$@"
        full_h=$LAY_LOGO_H
        [ "$full_h" -ge $(( rows - reserve - FULL_LOGO_PAD_TOP )) ] && return 0
    fi
    fit_layout "$FF_MIN" "$MIN_INFO_W" "$MIN_INFO_H" "$MIN_LOGO_PAD_TOP" "$@"
    if [ "$LAY_LOGO_H" -le "$full_h" ]; then
        fit_layout "$FF_FULL" "$FULL_INFO_W" "$FULL_INFO_H" "$FULL_LOGO_PAD_TOP" "$@"
    fi
    return 0
}

# fit_layout <cfg> <info-w> <info-h> <logo-pad-top> <cols> <rows> [reserve]
# Sets, rather than echoes (the render size is only known after generating):
#   LAY_CFG     fastfetch config          LAY_LOGO  logo file, or "none"
#   LAY_W/LAY_H total render size         LAY_LOGO_H  rows the mark itself took
fit_layout() {
    local info_w="$2" info_h="$3" pad_top="$4" cols="$5" rows="$6" reserve="${7:-0}" w h
    LAY_CFG="$1"
    LAY_LOGO="$(render_logo $(( cols - info_w - LOGO_MARGIN )) \
                            $(( rows - reserve - pad_top )))"
    if [ "$LAY_LOGO" = none ]; then
        LAY_LOGO_H=0; LAY_W=$info_w; LAY_H=$info_h
        return 0
    fi
    # The generator preserves the mark's aspect ratio, so it usually comes back
    # smaller than the box it was given — measure what it actually produced.
    read -r w h <<< "$(sed 's/\$1//' "$LAY_LOGO" |
        awk '{ if (length($0) > w) w = length($0); h++ } END { print w+0, h+0 }')"
    LAY_LOGO_H=$h
    LAY_W=$(( w + LOGO_MARGIN + info_w ))
    LAY_H=$(( h + pad_top ))
    [ "$LAY_H" -lt "$info_h" ] && LAY_H=$info_h
    return 0
}

# Echo a path to a logo that fits in <cols>x<rows> cells, or "none".
# Renders are cached per size: the banner is redrawn on every run, and at large
# sizes this is the only part that costs more than a few milliseconds.
render_logo() {
    local cols="$1" rows="$2" out="$RUNDIR/yaya-logo-${1}x${2}.txt"
    if [ "$cols" -lt "$LOGO_MIN_W" ] || [ "$rows" -lt 6 ]; then
        echo none; return
    fi
    if [ -s "$out" ] || python3 "$LOGO_GEN" "$cols" "$rows" "$out" 2>/dev/null; then
        echo "$out"; return
    fi
    # No python3/Pillow/source PNG — fall back to the largest static logo that fits.
    rm -f "$out"
    if   [ "$cols" -ge 40 ] && [ "$rows" -ge 22 ]; then echo "$LOGO_BIG"
    elif [ "$cols" -ge 22 ] && [ "$rows" -ge 12 ]; then echo "$LOGO_SMALL"
    else                                                echo none
    fi
}

show_banner() {
    # Leaves room for the "Press Ctrl+C" line and the first lines of ffmpeg
    # chatter, which scroll in underneath this banner.
    pick_layout "$(tput cols 2>/dev/null || echo 80)" \
                "$(tput lines 2>/dev/null || echo 24)" 3
    if [ "$LAY_LOGO" = none ]; then
        fastfetch --config "$LAY_CFG" --logo none 2>/dev/null
    else
        fastfetch --config "$LAY_CFG" --file "$LAY_LOGO" 2>/dev/null
    fi
}

# Render the banner centered in the terminal. Fastfetch aligns its info column
# with cursor-movement escapes, so prefixing its output with spaces misplaces
# the first info line — instead the whole render is shifted with
# --logo-padding-left (which overrides the configs' left padding of 1, hence
# the +1) using the measured sizes pick_layout reports. The no-logo variant
# ignores that flag but emits only plain color-escaped lines, so plain space
# prefixing is safe there.
show_banner_centered() {
    local cols rows pad_left pad_top i
    cols="$(tput cols 2>/dev/null || echo 80)"
    rows="$(tput lines 2>/dev/null || echo 24)"
    # Two rows held back: fastfetch ends its render with a newline, and the
    # centering pad adds one above. Without them the terminal scrolls and the
    # top of the mark is lost off-screen.
    pick_layout "$cols" "$rows" 2
    pad_left=$(( (cols - LAY_W) / 2 ));  [ "$pad_left" -lt 0 ] && pad_left=0
    pad_top=$(( (rows - LAY_H) / 2 ));   [ "$pad_top" -lt 0 ] && pad_top=0
    clear
    for ((i = 0; i < pad_top; i++)); do echo; done
    if [ "$LAY_LOGO" = none ]; then
        fastfetch --config "$LAY_CFG" --logo none 2>/dev/null \
            | sed "s/^/$(printf '%*s' "$pad_left" '')/"
    else
        fastfetch --config "$LAY_CFG" --file "$LAY_LOGO" \
            --logo-padding-left $(( pad_left + 1 )) 2>/dev/null
    fi
}

# Final render: a tmux session with the banner centered in the window and the
# latest ffmpeg "frame=" capture line on the tmux status bar (bottom line),
# refreshed every second. ffmpeg separates progress updates with \r, so the
# log's last frame line is recovered by turning \r into newlines first.
#
# Runs on its own tmux server (-L) so the pane inherits this shell's exported
# YAYA_* env even when a regular tmux server is already up, our status-line
# settings can't leak into other sessions, and a nested attach from inside an
# existing tmux client just works (with TMUX cleared).
launch_dashboard() {
    local session="yaya-webcam" tm="tmux -L yaya-webcam"
    if ! command -v tmux > /dev/null 2>&1; then
        show_banner
        echo "Press Ctrl+C to stop streaming."
        run_stream
        return
    fi
    $tm kill-session -t "$session" 2>/dev/null
    # -x/-y: size the detached session to this terminal, so the banner centers
    # against the real geometry instead of tmux's 80x24 default.
    $tm new-session -d -s "$session" -n webcam \
        -x "$(tput cols 2>/dev/null || echo 80)" \
        -y "$(tput lines 2>/dev/null || echo 24)" \
        "'$0' --pane"
    $tm set -t "$session" status on
    $tm set -t "$session" status-interval 1
    $tm set -t "$session" status-style "bg=black,fg=green"
    $tm set -t "$session" "status-format[0]" \
        "#[align=centre]#(tr '\r' '\n' < '$LOG' | grep -a 'frame=' | tail -n 1)"
    TMUX='' $tm attach -t "$session"
}

run_stream() {
    # `kill 0` is the only reliable way to take down both halves of the
    # gphoto2|ffmpeg pipeline, but it hits the whole process group — so arm it
    # only when this process leads its own group. True under an interactive
    # shell; not true if we're called from another script, hence the guard.
    if [ "$(ps -o pgid= -p $$ 2>/dev/null | tr -d ' ')" = "$$" ]; then
        trap 'kill 0 2>/dev/null' EXIT INT TERM
    fi
    local port model
    IFS=$'\t' read -r port model <<< "$(detect_camera)"
    if [ -z "$port" ]; then
        echo "No camera matching '$CAM_MATCH' is attached. gphoto2 sees:"
        echo
        gphoto2 --auto-detect 2>&1
        echo
        echo "Set YAYA_CAM_MATCH to a substring of the model you want, then rerun."
        return 1
    fi
    echo "Streaming $model ($port) to /dev/video42 — select 'Dummy video device' in your app."
    echo
    # --port pins the capture to the matched body, so a phone or a second PTP
    # device showing up on the bus can't win the race.
    eval "${YAYA_STREAM_CMD:-gphoto2 --port '$port' --stdout --capture-movie \
        | ffmpeg -i - -vcodec rawvideo -pix_fmt nv12 -threads 0 -f v4l2 /dev/video42}" 2>&1 \
        | tee "$LOG"
}

PLAIN=0
if [ "${1:-}" = "--plain" ] || [ "${1:-}" = "--no-dashboard" ]; then
    PLAIN=1
fi

# Internal: we are the tmux pane started by launch_dashboard. The outer run
# already did preflight and waited for the camera, so go straight to rendering.
# The stream's chatter is dropped here — tee inside run_stream still writes
# $LOG, which is where the status bar reads the frame counter from.
if [ "${1:-}" = "--pane" ]; then
    tput civis 2>/dev/null
    trap 'tput cnorm 2>/dev/null' EXIT
    show_banner_centered
    run_stream > /dev/null
    tput cnorm 2>/dev/null
    echo
    echo "Stream ended. Last log lines ($LOG):"
    tr '\r' '\n' < "$LOG" 2>/dev/null | tail -n 5
    sleep 15
    exit 0
fi

# --------------------------------------------------------------- preflight ---
# The streaming stack is not part of the base ISO — point the user at it
# instead of failing halfway through with a cryptic pipeline error.
for dep in gphoto2 ffmpeg; do
    if ! command -v "$dep" > /dev/null 2>&1; then
        echo "Missing dependency: $dep"
        echo "Install the streaming stack first:"
        echo "  sudo apt install gphoto2 ffmpeg v4l2loopback-dkms"
        exit 1
    fi
done

# gvfs-gphoto2-volume-monitor (and any stale capture from a previous run) claims
# the camera over PTP and makes --capture-movie fail to open it. Plain pkill
# matches process names, not full command lines, so this hits gphoto2 and
# gvfs*-gphoto2* without touching unrelated shells that merely mention gphoto2.
echo "Clearing anything holding the camera..."
sudo pkill gphoto2 || true
sleep 1

# Make sure the v4l2loopback module is actually built for the *running* kernel.
# After a kernel upgrade, DKMS can't rebuild it until matching headers are installed.
if ! /sbin/modinfo v4l2loopback > /dev/null 2>&1; then
    echo "v4l2loopback is not built for the running kernel ($(uname -r))."
    if [ ! -d "/lib/modules/$(uname -r)/build" ]; then
        echo "Kernel headers are missing. Installing headers and rebuilding via DKMS..."
        # linux-headers-amd64 keeps headers coming with future kernel upgrades,
        # the versioned package covers the currently running kernel.
        sudo apt-get install -y linux-headers-amd64 "linux-headers-$(uname -r)" || exit 1
    fi
    sudo dkms autoinstall -k "$(uname -r)" || exit 1
fi

echo "Loading v4l2loopback module..."
if ! sudo modprobe v4l2loopback exclusive_caps=1 max_buffers=2 video_nr=42; then
    echo "Error loading v4l2loopback. Are you sure Secure Boot is disabled?"
    exit 1
fi

echo "Waiting for a '$CAM_MATCH' camera..."
while [ -z "$(detect_camera)" ]; do
    echo "No '$CAM_MATCH' detected. Plug in your DSLR via USB, turn it on, and ensure it's in PC/PTP/Webcam mode."
    sleep 5
done
IFS=$'\t' read -r CAM_PORT CAM_MODEL <<< "$(detect_camera)"
echo "Camera detected: $CAM_MODEL ($CAM_PORT)"

# --------------------------------------------------------------- dispatch ---
if [ "$PLAIN" = 1 ]; then
    echo "Press Ctrl+C to stop streaming."
    run_stream
else
    launch_dashboard
fi
