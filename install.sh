#!/bin/sh
# ==============================================================================
# Alpine-SSH: Dual-Mode Automated Installer & Staging Deployer
# Specially engineered for Alpine Linux (musl-libc, OpenRC)
#
# Supported Installation Modes:
#   [1] Online Install: Download & install from GitHub / Gitea / Custom Git
#   [2] Local Folder Install: Auto-detects local project folder and installs
#       instantly by copying pre-compiled static binaries (Fast & Offline)
# ==============================================================================

set -e

# --- Color Definitions (POSIX compliant) ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'
BOLD='\033[1m'

DEFAULT_GITHUB_REPO="risqinf/sshws"
DEFAULT_GITHUB_BRANCH="main"

# --- UI Helpers ---
print_header() {
    clear 2>/dev/null || true
    printf "%b━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━%b\n" "$CYAN" "$NC"
    printf "%b%b        AUTOSCRIPT VPN - OFFICIAL RELEASE                   %b\n" "$BOLD" "$PURPLE" "$NC"
    printf "%b%b                Target OS: Alpine Linux                     %b\n" "$BOLD" "$CYAN" "$NC"
    printf "%b━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━%b\n" "$CYAN" "$NC"
}

print_ok()   { printf " %b[OK]%b %s\n" "$GREEN" "$NC" "$1"; }
print_info() { printf " %b[INFO]%b %s\n" "$CYAN" "$NC" "$1"; }
print_warn() { printf " %b[WARN]%b %s\n" "$YELLOW" "$NC" "$1"; }
print_err()  { printf " %b[ERR]%b %s\n" "$RED" "$NC" "$1"; }

# ==============================================================================
# Directory & Project Detection Helpers
# ==============================================================================

# Returns 0 if directory contains valid alpine-ssh project components
is_valid_project_dir() {
    _dir="$1"
    [ -z "$_dir" ] && return 1
    [ ! -d "$_dir" ] && return 1

    # Check 1: Pre-compiled binaries
    if [ -f "$_dir/bin/alpinessh" ] && [ -f "$_dir/bin/ssh-ws" ]; then
        return 0
    fi
    # Check 2: Architecture specific binaries
    if [ -f "$_dir/bin/amd64/alpinessh" ] || [ -f "$_dir/bin/arm64/alpinessh" ]; then
        return 0
    fi
    # Check 3: Source files
    if [ -f "$_dir/include/alpinessh.h" ] || [ -f "$_dir/src/main.c" ] || [ -f "$_dir/src/installer.c" ]; then
        return 0
    fi
    # Check 4: Configuration & OpenRC templates
    if [ -f "$_dir/conf/haproxy.cfg" ] && [ -f "$_dir/openrc/ssh-ws.initd" ]; then
        return 0
    fi
    # Check 5: Distribution static archive
    if [ -f "$_dir/dist/alpinessh-binaries-linux-amd64.tar.gz" ] || [ -f "$_dir/dist/alpinessh-static-linux-amd64.tar.gz" ]; then
        return 0
    fi

    return 1
}

detect_project_dir() {
    PROJECT_DIR=""

    # 1. Check directory where this script is located
    SCRIPT_PATH="$0"
    SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" 2>/dev/null && pwd)"
    if is_valid_project_dir "$SCRIPT_DIR"; then
        PROJECT_DIR="$SCRIPT_DIR"
        return 0
    fi

    # 2. Check current working directory
    CURRENT_DIR="$(pwd 2>/dev/null)"
    if is_valid_project_dir "$CURRENT_DIR"; then
        PROJECT_DIR="$CURRENT_DIR"
        return 0
    fi

    # 3. Check subdirectories 'alpine-ssh'
    if is_valid_project_dir "$CURRENT_DIR/alpine-ssh"; then
        PROJECT_DIR="$CURRENT_DIR/alpine-ssh"
        return 0
    fi
    if is_valid_project_dir "$SCRIPT_DIR/alpine-ssh"; then
        PROJECT_DIR="$SCRIPT_DIR/alpine-ssh"
        return 0
    fi

    # 4. Check standard VPS directories
    if is_valid_project_dir "/root/alpine-ssh"; then
        PROJECT_DIR="/root/alpine-ssh"
        return 0
    fi
    if is_valid_project_dir "$HOME/alpine-ssh"; then
        PROJECT_DIR="$HOME/alpine-ssh"
        return 0
    fi
    if is_valid_project_dir "/etc/alpinessh/source"; then
        PROJECT_DIR="/etc/alpinessh/source"
        return 0
    fi

    return 1
}

check_binary_status() {
    _pdir="$1"
    _arch="$2"
    BIN_SRC=""

    if [ -d "$_pdir/bin/$_arch" ] && [ -f "$_pdir/bin/$_arch/alpinessh" ] && [ -f "$_pdir/bin/$_arch/ssh-ws" ]; then
        BIN_SRC="$_pdir/bin/$_arch"
    elif [ -d "$_pdir/bin" ] && [ -f "$_pdir/bin/alpinessh" ] && [ -f "$_pdir/bin/ssh-ws" ]; then
        BIN_SRC="$_pdir/bin"
    elif [ -f "$_pdir/dist/alpinessh-binaries-linux-amd64.tar.gz" ] && [ "$_arch" = "amd64" ]; then
        mkdir -p "$_pdir/bin"
        tar -xzf "$_pdir/dist/alpinessh-binaries-linux-amd64.tar.gz" -C "$_pdir/bin" 2>/dev/null || true
        if [ -f "$_pdir/bin/alpinessh" ] && [ -f "$_pdir/bin/ssh-ws" ]; then
            BIN_SRC="$_pdir/bin"
        fi
    fi
}

# ==============================================================================
# MODE 1: Online Installation (GitHub / Gitea / Custom Git)
# ==============================================================================
run_online_install() {
    print_header
    printf "%bMode 1: Instalasi Online (GitHub / Gitea / Remote Repository)%b\n" "$WHITE" "$NC"
    printf "%b────────────────────────────────────────────────────────────%b\n" "$CYAN" "$NC"

    # Root check
    if [ "$(id -u)" -ne 0 ]; then
        print_err "Installer ini harus dijalankan sebagai root di VPS Alpine!"
        exit 1
    fi

    # Enable community repo on Alpine if commented
    sed -i 's/^#\(.*\/community\)/\1/' /etc/apk/repositories 2>/dev/null || true

    # Check fetch tool: curl or wget
    FETCH_CMD=""
    if command -v curl >/dev/null 2>&1; then
        FETCH_CMD="curl -fsSL"
    elif command -v wget >/dev/null 2>&1; then
        FETCH_CMD="wget -qO-"
    else
        apk update >/dev/null 2>&1 || true
        apk add --no-cache curl wget >/dev/null 2>&1 || true
        if command -v curl >/dev/null 2>&1; then
            FETCH_CMD="curl -fsSL"
        else
            FETCH_CMD="wget -qO-"
        fi
    fi

    # Automatic repository target (Default: GitHub risqinf/sshws)
    REPO_TARGET="${ONLINE_REPO_URL:-$DEFAULT_GITHUB_REPO}"
    REPO_TYPE="github_default"

    case "$REPO_TARGET" in
        *.tar.gz|*.zip)
            REPO_TYPE="direct_archive"
            ;;
        http*github.com*|*/*)
            REPO_TYPE="github_default"
            REPO_TARGET="${REPO_TARGET#https://github.com/}"
            REPO_TARGET="${REPO_TARGET#http://github.com/}"
            REPO_TARGET="${REPO_TARGET%.git}"
            ;;
        http*|git@*)
            REPO_TYPE="gitea_git"
            ;;
    esac

    TARGET_DIR="/root/alpine-ssh"
    print_info "Mempersiapkan folder instalasi di: $TARGET_DIR..."
    mkdir -p "$TARGET_DIR"

    DOWNLOAD_SUCCESS=0

    # 1. Try static release tar.gz (fastest, pre-compiled static binary)
    if [ "$REPO_TYPE" = "github_default" ] || [ "$REPO_TYPE" = "github_custom" ]; then
        TAR_URL="https://raw.githubusercontent.com/${REPO_TARGET}/${DEFAULT_GITHUB_BRANCH}/dist/alpinessh-static-linux-amd64.tar.gz"
        ZIP_URL="https://github.com/${REPO_TARGET}/archive/refs/heads/${DEFAULT_GITHUB_BRANCH}.zip"

        print_info "Mengunduh static release archive ($TAR_URL)..."
        TMP_ARCHIVE="/tmp/alpinessh_online_$$.tar.gz"
        if $FETCH_CMD "$TAR_URL" > "$TMP_ARCHIVE" 2>/dev/null && [ -s "$TMP_ARCHIVE" ]; then
            print_ok "Berhasil mengunduh static release archive!"
            tar -xzf "$TMP_ARCHIVE" -C "$TARGET_DIR" 2>/dev/null || true
            rm -f "$TMP_ARCHIVE"
            DOWNLOAD_SUCCESS=1
        else
            rm -f "$TMP_ARCHIVE"
            print_warn "Static archive tidak ditemukan di raw branch. Mencoba download source zip ($ZIP_URL)..."
            TMP_ZIP="/tmp/alpinessh_online_$$.zip"
            if $FETCH_CMD "$ZIP_URL" > "$TMP_ZIP" 2>/dev/null && [ -s "$TMP_ZIP" ]; then
                command -v unzip >/dev/null 2>&1 || apk add --no-cache unzip >/dev/null 2>&1 || true
                rm -rf "/tmp/alpine_extracted_$$"
                mkdir -p "/tmp/alpine_extracted_$$"
                unzip -q -o "$TMP_ZIP" -d "/tmp/alpine_extracted_$$" 2>/dev/null || true
                EXTRACTED_SUB="$(find "/tmp/alpine_extracted_$$" -mindepth 1 -maxdepth 1 -type d | head -n 1)"
                if [ -n "$EXTRACTED_SUB" ] && [ -d "$EXTRACTED_SUB" ]; then
                    cp -rf "$EXTRACTED_SUB"/* "$TARGET_DIR"/ 2>/dev/null || true
                    cp -rf "$EXTRACTED_SUB"/.* "$TARGET_DIR"/ 2>/dev/null || true
                fi
                rm -rf "/tmp/alpine_extracted_$$" "$TMP_ZIP"
                DOWNLOAD_SUCCESS=1
                print_ok "Berhasil mengunduh dan mengekstrak source repository!"
            fi
        fi
    elif [ "$REPO_TYPE" = "direct_archive" ]; then
        print_info "Mengunduh file archive dari: $REPO_TARGET..."
        TMP_FILE="/tmp/alpinessh_direct_$$"
        $FETCH_CMD "$REPO_TARGET" > "$TMP_FILE" 2>/dev/null || true
        if [ -s "$TMP_FILE" ]; then
            if tar -tzf "$TMP_FILE" >/dev/null 2>&1; then
                tar -xzf "$TMP_FILE" -C "$TARGET_DIR"
                DOWNLOAD_SUCCESS=1
            elif unzip -t "$TMP_FILE" >/dev/null 2>&1; then
                command -v unzip >/dev/null 2>&1 || apk add --no-cache unzip >/dev/null 2>&1 || true
                unzip -q -o "$TMP_FILE" -d "$TARGET_DIR"
                DOWNLOAD_SUCCESS=1
            fi
        fi
        rm -f "$TMP_FILE"
    fi

    # Fallback to git clone if archive didn't succeed
    if [ "$DOWNLOAD_SUCCESS" -ne 1 ]; then
        print_info "Menggunakan Git Clone sebagai fallback..."
        command -v git >/dev/null 2>&1 || apk add --no-cache git >/dev/null 2>&1 || true
        CLONE_URL="$REPO_TARGET"
        case "$REPO_TARGET" in
            http*|git@*) ;;
            */*) CLONE_URL="https://github.com/${REPO_TARGET}.git" ;;
        esac
        rm -rf "$TARGET_DIR"
        git clone --depth 1 "$CLONE_URL" "$TARGET_DIR" 2>/dev/null || true
        if is_valid_project_dir "$TARGET_DIR"; then
            DOWNLOAD_SUCCESS=1
            print_ok "Git clone berhasil ke: $TARGET_DIR"
        fi
    fi

    if [ "$DOWNLOAD_SUCCESS" -ne 1 ] || ! is_valid_project_dir "$TARGET_DIR"; then
        print_err "Gagal mengunduh atau memverifikasi folder Alpine-SSH dari sumber online!"
        echo "Pastikan repository dapat diakses publik atau gunakan Opsi 2 (Upload folder langsung ke VPS)."
        exit 1
    fi

    print_ok "Folder alpine-ssh siap di: $TARGET_DIR"
    PROJECT_DIR="$TARGET_DIR"

    # Lanjut langsung ke instalasi lokal
    run_local_alpine_install
}

# ==============================================================================
# MODE 2: Local Folder Installation (Fast Copy Mode)
# ==============================================================================
run_local_alpine_install() {
    print_header
    printf "%bMode 2: Eksekusi Instalasi Folder Lokal (Cepat & Siap)...%b\n" "$WHITE" "$NC"
    printf "%b────────────────────────────────────────────────────────────%b\n" "$CYAN" "$NC"

    # 1. Root check
    if [ "$(id -u)" -ne 0 ]; then
        print_err "Installer ini harus dijalankan sebagai root di VPS Alpine!"
        exit 1
    fi

    # 2. Lock Project Directory
    if [ -z "$PROJECT_DIR" ]; then
        detect_project_dir || true
    fi

    if [ -z "$PROJECT_DIR" ] || ! is_valid_project_dir "$PROJECT_DIR"; then
        print_warn "Folder lokal alpine-ssh tidak ditemukan atau komponen belum lengkap!"
        print_info "Beralih otomatis ke Mode 1: Download dari GitHub / Gitea..."
        run_online_install
        return 0
    fi

    PROJECT_DIR="$(cd "$PROJECT_DIR" && pwd)"
    print_ok "Folder Terdeteksi & Dikunci: $PROJECT_DIR"

    # 3. OS Verification
    if [ ! -f /etc/alpine-release ]; then
        print_err "/etc/alpine-release tidak ditemukan! Target OS harus Alpine Linux."
        echo "Jika Anda berada di PC/VPS lain, gunakan opsi Remote VPS Deployer."
        exit 1
    fi
    ALPINE_VER="$(cat /etc/alpine-release)"
    print_ok "Sistem Terverifikasi: Alpine Linux v${ALPINE_VER}"

    # 4. Architecture Detection
    ARCH="$(uname -m)"
    case "$ARCH" in
        x86_64|amd64)     SYS_ARCH="amd64" ;;
        aarch64|arm64)    SYS_ARCH="arm64" ;;
        armv7l|armhf|arm) SYS_ARCH="arm" ;;
        *)                SYS_ARCH="amd64" ;;
    esac
    print_ok "Arsitektur CPU Terdeteksi: ${ARCH} (Target: ${SYS_ARCH})"

    # 5. Check Pre-Compiled Static Binaries
    check_binary_status "$PROJECT_DIR" "$SYS_ARCH"
    if [ -n "$BIN_SRC" ]; then
        print_ok "Status Binary: PRE-COMPILED STATIC READY (di $BIN_SRC)"
        print_ok "Mode Eksekusi: INSTAN (Copy Binary Saja - Tanpa Compile Ulang)"
    else
        print_warn "Binary pre-compiled untuk $SYS_ARCH tidak ditemukan di bin/. Akan dikompilasi dari source."
    fi

    # 6. Domain Setup
    DOMAIN_INPUT="${CLI_DOMAIN:-}"
    if [ -z "$DOMAIN_INPUT" ]; then
        if [ -t 0 ] && [ -r /dev/tty ]; then
            printf "\n"
            printf "%b────────────────────────────────────────────────────────────%b\n" "$CYAN" "$NC"
            printf " %b[PROMPT]%b Masukkan Domain VPS (contoh: vpn.domainanda.com)\n" "$YELLOW" "$NC"
            printf " Atau tekan ENTER jika ingin menggunakan SSL sementara (Self-Signed): "
            read -r DOMAIN_INPUT < /dev/tty 2>/dev/null || DOMAIN_INPUT=""
            printf "%b────────────────────────────────────────────────────────────%b\n" "$CYAN" "$NC"
        else
            DOMAIN_INPUT=""
        fi
    fi

    if [ -n "$DOMAIN_INPUT" ]; then
        mkdir -p /etc/alpinessh
        echo "$DOMAIN_INPUT" > /etc/alpinessh/domain
        print_ok "Domain disetel: $DOMAIN_INPUT"
    else
        print_info "Menggunakan Self-Signed SSL sementara (dapat diubah nanti di menu)."
    fi

    # 7. Setup System Directories
    mkdir -p /usr/local/bin /usr/sbin /usr/bin /etc/alpinessh /etc/alpinessh/ssl /etc/haproxy /etc/nginx/http.d /etc/init.d /var/log

    # Enable community repo on Alpine if commented
    sed -i 's/^#\(.*\/community\)/\1/' /etc/apk/repositories 2>/dev/null || true

    # 8. Install Alpine Packages (Fast runtime only when binaries exist)
    print_info "Mengupdate apk & menginstall runtime packages yang dibutuhkan..."
    apk update

    RUNTIME_PKGS="nginx haproxy curl wget unzip tar gzip bzip2 openssh openssh-server iptables \
                  coreutils procps busybox-extras sqlite openssl certbot tzdata shadow nano \
                  dropbear dropbear-dbclient dropbear-scp"

    if [ -n "$BIN_SRC" ]; then
        print_info "Binary statis terdeteksi: Melewati compiler toolchain (Deploy VPS Sangat Cepat!)"
        apk add --no-cache $RUNTIME_PKGS
    else
        print_warn "Menginstall compiler toolchain (gcc, musl-dev, make) untuk kompilasi source..."
        apk add --no-cache $RUNTIME_PKGS gcc musl-dev make
    fi

    # 9. Deploy Pre-compiled Static Binaries
    if [ -n "$BIN_SRC" ]; then
        [ -f "$BIN_SRC/alpinessh" ] && cp -f "$BIN_SRC/alpinessh" /usr/local/bin/alpinessh
        [ -f "$BIN_SRC/ssh-ws" ] && cp -f "$BIN_SRC/ssh-ws" /usr/local/bin/ssh-ws
        [ -f "$BIN_SRC/dropbear" ] && cp -f "$BIN_SRC/dropbear" /usr/sbin/dropbear
        [ -f "$BIN_SRC/dropbearkey" ] && cp -f "$BIN_SRC/dropbearkey" /usr/bin/dropbearkey
        [ -f "$BIN_SRC/dropbearconvert" ] && cp -f "$BIN_SRC/dropbearconvert" /usr/bin/dropbearconvert
        [ -f "$BIN_SRC/scp" ] && cp -f "$BIN_SRC/scp" /usr/bin/scp
        [ -f "$BIN_SRC/dbclient" ] && cp -f "$BIN_SRC/dbclient" /usr/bin/dbclient
        chmod +x /usr/local/bin/alpinessh /usr/local/bin/ssh-ws 2>/dev/null || true
        [ -f /usr/sbin/dropbear ] && chmod +x /usr/sbin/dropbear 2>/dev/null || true
        [ -f /usr/bin/dropbearkey ] && chmod +x /usr/bin/dropbearkey 2>/dev/null || true
        print_ok "Binary statis berhasil disalin ke /usr/local/bin dan /usr/sbin."
    fi

    # Compile fallback if binary not present (e.g. on new ARM hardware without pre-builds)
    if [ ! -x /usr/local/bin/alpinessh ] || [ ! -x /usr/local/bin/ssh-ws ]; then
        print_info "Mengompilasi native C static core untuk ${SYS_ARCH}..."
        cd "$PROJECT_DIR"
        make static 2>/dev/null || make all
        if [ -f bin/alpinessh ]; then
            cp -f bin/alpinessh /usr/local/bin/alpinessh
            chmod +x /usr/local/bin/alpinessh
        fi
        if [ -f bin/ssh-ws ]; then
            cp -f bin/ssh-ws /usr/local/bin/ssh-ws
            chmod +x /usr/local/bin/ssh-ws
        fi
        if [ ! -x /usr/local/bin/alpinessh ] || [ ! -x /usr/local/bin/ssh-ws ]; then
            print_err "Gagal menemukan atau mengompilasi binary /usr/local/bin/alpinessh!"
            exit 1
        fi
        print_ok "Native C binaries berhasil dikompilasi dan dipasang."
    fi

    # 10. Copy Configurations & OpenRC Service Templates
    [ -f "$PROJECT_DIR/conf/haproxy.cfg" ] && cp -f "$PROJECT_DIR/conf/haproxy.cfg" /etc/haproxy/haproxy.cfg
    [ -f "$PROJECT_DIR/conf/alpinessh-nginx.conf" ] && cp -f "$PROJECT_DIR/conf/alpinessh-nginx.conf" /etc/nginx/http.d/alpinessh.conf
    [ -f "$PROJECT_DIR/conf/alpinessh.conf" ] && cp -f "$PROJECT_DIR/conf/alpinessh.conf" /etc/alpinessh/alpinessh.conf
    [ -f "$PROJECT_DIR/conf/dropbear.conf" ] && cp -f "$PROJECT_DIR/conf/dropbear.conf" /etc/dropbear/dropbear.conf 2>/dev/null || true

    # Deploy OpenRC init scripts
    if [ -f "$PROJECT_DIR/openrc/ssh-ws.initd" ]; then
        cp -f "$PROJECT_DIR/openrc/ssh-ws.initd" /etc/init.d/ssh-ws
        chmod 755 /etc/init.d/ssh-ws
    fi
    if [ -f "$PROJECT_DIR/openrc/alpinessh-limiter.initd" ]; then
        cp -f "$PROJECT_DIR/openrc/alpinessh-limiter.initd" /etc/init.d/alpinessh-limiter
        chmod 755 /etc/init.d/alpinessh-limiter
    fi

    # 11. Setup Nadia Store SSH Login Banner
    print_info "Memasang banner resmi login Nadia Store..."
    mkdir -p /etc/alpinessh
    if [ -f "$PROJECT_DIR/conf/issue.net" ]; then
        cp -f "$PROJECT_DIR/conf/issue.net" /etc/alpinessh/issue.net
        cp -f "$PROJECT_DIR/conf/issue.net" /etc/issue.net
    else
        cat << 'BANNER_EOF' > /etc/alpinessh/issue.net
<p style="text-align:left"><b><font color="green">🇲🇨MANTAP BERHASIL CONECT VPN NYA🇲🇨


<p style="text-align:left"><b><font color="green">kalau lelet beli premium biar lancar dan stabil ya joint grup TELEGRAM 
👇
https://t.me/Nadia_Store_Chat

<p style="text-align:left"><b><font color="green">telegram channel
 https://t.me/channel_Nadia_Store

<p style="text-align:left"><b><font color="green"> ingat beli vpn nya di
👇
 https://www.nadiavpn.web.id/login
BANNER_EOF
        cp -f /etc/alpinessh/issue.net /etc/issue.net
    fi
    chmod 644 /etc/alpinessh/issue.net /etc/issue.net
    print_ok "SSH Login Banner terpasang."

    # 12. Create Convenient CLI Symlinks
    ln -sf /usr/local/bin/alpinessh /usr/local/bin/menu
    ln -sf /usr/local/bin/alpinessh /usr/local/bin/add-ssh
    ln -sf /usr/local/bin/alpinessh /usr/local/bin/cek-ssh
    ln -sf /usr/local/bin/alpinessh /usr/local/bin/trial-ssh
    ln -sf /usr/local/bin/alpinessh /usr/local/bin/del-ssh
    ln -sf /usr/local/bin/alpinessh /usr/local/bin/renew-ssh
    ln -sf /usr/local/bin/alpinessh /usr/local/bin/list-ssh
    ln -sf /usr/local/bin/alpinessh /usr/local/bin/config-ssh
    ln -sf /usr/local/bin/alpinessh /usr/local/bin/history-ssh

    # 13. Execute Compiled Native C System Installer
    print_header
    printf "%bMenjalankan Core System Installer (alpinessh install)...%b\n" "$WHITE" "$NC"
    printf "%b────────────────────────────────────────────────────────────%b\n" "$CYAN" "$NC"

    /usr/local/bin/alpinessh install "$DOMAIN_INPUT"
}

# ==============================================================================
# Remote VPS Deployer (For Non-Alpine developer machines)
# ==============================================================================
run_remote_deployer() {
    print_header
    printf "%bRemote VPS Deployer: Upload alpine-ssh ke VPS Alpine Linux%b\n" "$WHITE" "$NC"
    printf "%b────────────────────────────────────────────────────────────%b\n" "$CYAN" "$NC"

    detect_project_dir || true
    if [ -z "$PROJECT_DIR" ]; then
        print_err "Tidak dapat menemukan folder project alpine-ssh!"
        echo "Jalankan script ini dari dalam atau di samping folder alpine-ssh."
        exit 1
    fi

    printf " Local Project Dir : %b%s%b\n\n" "$GREEN" "$PROJECT_DIR" "$NC"

    printf " VPS IP Address / Host : "
    read -r VPS_HOST
    if [ -z "$VPS_HOST" ]; then
        print_err "IP Address VPS tidak boleh kosong!"
        exit 1
    fi

    printf " VPS SSH Port [22]     : "
    read -r VPS_PORT
    VPS_PORT="${VPS_PORT:-22}"

    printf " VPS SSH User [root]   : "
    read -r VPS_USER
    VPS_USER="${VPS_USER:-root}"

    printf "\n"
    print_info "Mengompres folder alpine-ssh lokal..."
    TEMP_TAR="/tmp/alpine_ssh_staging_$$.tar.gz"
    PARENT_DIR="$(cd "${PROJECT_DIR}/.." && pwd)"
    FOLDER_NAME="$(basename "$PROJECT_DIR")"

    tar -czf "$TEMP_TAR" \
        --exclude='.git' \
        --exclude='dist' \
        --exclude='*.o' \
        --exclude='*.zip' \
        -C "$PARENT_DIR" "$FOLDER_NAME"

    ARCHIVE_SIZE="$(du -h "$TEMP_TAR" 2>/dev/null | awk '{print $1}')"
    print_ok "Arsip dibuat ($ARCHIVE_SIZE)."

    print_info "Mengupload alpine-ssh ke $VPS_USER@$VPS_HOST:$VPS_PORT (/root/alpine-ssh)..."

    SSH_CMD="ssh -p $VPS_PORT -o StrictHostKeyChecking=no $VPS_USER@$VPS_HOST"

    if $SSH_CMD "rm -rf /root/alpine-ssh && mkdir -p /root && tar -xzf - -C /root" < "$TEMP_TAR"; then
        print_ok "Project berhasil diupload dan diekstrak ke remote /root/alpine-ssh."
    else
        print_err "Gagal upload via stream SSH. Mencoba SCP fallback..."
        scp -P "$VPS_PORT" -o StrictHostKeyChecking=no "$TEMP_TAR" "$VPS_USER@$VPS_HOST:/root/alpine-ssh.tar.gz"
        $SSH_CMD "mkdir -p /root/alpine-ssh && tar -xzf /root/alpine-ssh.tar.gz -C /root && rm -f /root/alpine-ssh.tar.gz"
    fi

    rm -f "$TEMP_TAR"

    printf "\n"
    print_info "Menjalankan instalasi lokal langsung di VPS Alpine via Native Core..."
    printf "%b────────────────────────────────────────────────────────────%b\n" "$CYAN" "$NC"

    $SSH_CMD "cd /root/alpine-ssh && chmod +x install.sh && sh install.sh --local"
}

# ==============================================================================
# Entry Point & CLI Dispatcher
# ==============================================================================

FORCE_LOCAL=0
FORCE_ONLINE=0
ONLINE_REPO_URL=""

while [ $# -gt 0 ]; do
    case "$1" in
        --local|-l)
            FORCE_LOCAL=1
            shift
            ;;
        --online|-o)
            FORCE_ONLINE=1
            shift
            ;;
        --repo)
            ONLINE_REPO_URL="$2"
            FORCE_ONLINE=1
            shift 2
            ;;
        --domain|-d)
            CLI_DOMAIN="$2"
            shift 2
            ;;
        --help|-h)
            printf "Autoscript VPN Installer - Fully Automated (Online & Local)\n\n"
            printf "Usage: sh install.sh [OPTIONS]\n\n"
            printf "Options:\n"
            printf "  --local, -l            Force install using local folder\n"
            printf "  --online, -o           Force online install from GitHub\n"
            printf "  --repo <URL|user/repo> Specify custom repository or archive URL\n"
            printf "  --domain, -d <domain>  Specify VPS domain for SSL\n"
            printf "  --help, -h             Show this help message\n\n"
            exit 0
            ;;
        *)
            shift
            ;;
    esac
done

IS_ALPINE=0
if [ -f /etc/alpine-release ] || (grep -qi "alpine" /etc/os-release 2>/dev/null); then
    IS_ALPINE=1
fi

if [ "$IS_ALPINE" -eq 1 ] || [ "$FORCE_LOCAL" -eq 1 ] || [ "$FORCE_ONLINE" -eq 1 ]; then
    detect_project_dir || true

    if [ "$FORCE_LOCAL" -eq 1 ]; then
        run_local_alpine_install
    elif [ "$FORCE_ONLINE" -eq 1 ]; then
        run_online_install
    else
        # Auto-detect mode: Instant local execution if folder exists, else download from GitHub
        if [ -n "$PROJECT_DIR" ] && is_valid_project_dir "$PROJECT_DIR"; then
            print_header
            printf " %b[STATUS]%b Folder Autoscript VPN Terdeteksi : %b%s%b\n" "$GREEN" "$NC" "$CYAN" "$PROJECT_DIR" "$NC"
            print_ok "Binary & Konfigurasi Siap: Melakukan instalasi instan dari folder lokal..."
            run_local_alpine_install
        else
            print_header
            print_info "Folder lokal belum ada. Mengunduh rilis otomatis dari GitHub: $DEFAULT_GITHUB_REPO..."
            run_online_install
        fi
    fi
else
    # Non-Alpine machine (e.g. developer laptop) -> Remote VPS deployer
    run_remote_deployer
fi
