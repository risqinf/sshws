# Autoscript VPN: Native Static SSH Tunneling & Management Stack for Alpine Linux

Lightweight, high-performance, and minimal footprint **SSH-only** tunneling stack and management system engineered specifically for **Alpine Linux** (musl-libc & OpenRC init system).

---

## 🌟 Key Architecture & Highlights

- **Target OS**: **Alpine Linux** (OpenRC `/etc/init.d/`, `apk`, musl-libc).
- **Native C Core (`alpinessh`)**:
  - Compiled as a **100% Static Binary** (`-static`).
  - Zero dynamic runtime bloat (no Python, no Node.js, no Ruby).
  - Embedded **SQLite3** database for lightning-fast account storage and audit logs.
  - Interactive ANSI terminal TUI dashboard (`menu`).
- **Core WebSocket & Multiplexer Engine (`ssh-ws`)**:
  - Developed in **Pure C** for minimal RAM (< 10MB) and maximum throughput.
  - **Multi Payload & Dual Payload Engine**: Supports single-buffer chained dual payloads and interactive split payloads (`[split]`) with automatic probe `200 OK` responses.
  - **Wild HTTP Support**: Handles ANY method (`HEAD`, `GET`, `POST`, `OPTIONS`, `PATCH`, `PUT`, `DELETE`, etc.), ANY HTTP version (`HTTP/69`, `HTTP/99`, `HTTP/1.1`, etc.), and ANY custom path (`/cgi`, `/cdn-cgi/trace`, `/ssh`, `/ws`, `/`, etc.).
  - **HAProxy L7 Direct Routing**: Bypasses Nginx strict parsers for all WebSocket/HTTP payloads to eliminate `400 Bad Request` and `505 Version Not Supported` errors.
  - **PROXY Protocol v1 Parser**: Preserves true client IP and port from upstream HAProxy `send-proxy`.
  - **Trailing Byte Forwarding**: Automatically identifies and forwards pipelined client SSH banners (`SSH-2.0...`) to Dropbear without losing a single byte.
  - Multi-threaded epoll/poll-based I/O handling thousands of concurrent tunnels.
  - Dual-mode protocol detection: transparently proxies both WebSocket frames and raw SSH direct payloads.
  - Built-in live log follower for Alpine Linux syslog (`/var/log/messages`).
  - Built-in HTTP REST API on port `8081` (`/api/sessions`, `/api/status`, `/api/account/*`, `/health`).
  - Integrated BadVPN UDPGW multiplexer on port `7300` for gaming and VoIP.
- **System Features**:
  - **Instant VPS Deployment**: Drop-in precompiled static binaries without requiring heavy compiler toolchains.
  - **Autobackup to Telegram Bot**: Multipart `.tar.gz` archive upload via Telegram Bot API with detailed HTML reports.
  - **System Restore**: One-command restore from Telegram File ID or local archive.
  - **Change Domain**: Instant domain reconfiguration with automated SSL provisioning.
  - **SSL Renewal**: Automated Let's Encrypt / ZeroSSL ACME certificate issuance and weekly renewal cron.
  - **Multi-Login IP Limiter**: Background daemon monitoring active sessions and enforcing concurrent IP limits.
  - **Auto-Expiry Engine**: Daily cleanup of expired SSH users with Telegram notification alerts.

---

## 🚀 Port Specifications

| Service | Port | Description |
| :--- | :--- | :--- |
| **OpenSSH** | `22` | Standard OpenSSH server with SSH login banner |
| **Dropbear SSH** | `109, 143` | Direct Dropbear SSH daemon for mobile/desktop clients |
| **SSH WebSocket (HTTP)** | `80, 8880` | HTTP WebSocket tunnel (CDN / Cloudflare / Bug Host compatible) |
| **SSH WebSocket (SSL/TLS)** | `443` | HTTPS WebSocket tunnel with TLS termination & ALPN |
| **SSH Direct (SSL/TLS)** | `443, 447` | Direct SSH over SSL/TLS (Port 443 via HAProxy Mux & Port 447 dedicated) |
| **BadVPN UDPGW** | `7300` | UDP Gateway for gaming and voice calls (WhatsApp/VoIP) |
| **Internal REST API** | `8081` | Real-time session metrics and connection manager (Loopback) |

---

## 📦 Pilihan Metode Instalasi (Alpine Linux)

Installer `install.sh` dilengkapi dengan deteksi cerdas yang mendukung **2 Opsi Instalasi**:

### 🌐 Opsi 1: Instalasi Online (Setelah Upload ke GitHub / Gitea / Remote Git)

Jalankan perintah satu baris berikut langsung di VPS Alpine Linux Anda sebagai `root`:

```bash
# Menggunakan GitHub Resmi (Default):
wget -qO install.sh https://raw.githubusercontent.com/risqinf/sshws/main/install.sh && sh install.sh

# Atau menggunakan curl:
curl -fsSL https://raw.githubusercontent.com/risqinf/sshws/main/install.sh | sh
```

> **Catatan Fleksibilitas**: Jika Anda meng-host di **Gitea**, **GitLab**, atau repository GitHub pribadi:
> Cukup jalankan `sh install.sh` dan pilih Opsi `[2] Custom GitHub` atau `[3] Gitea / Custom Git URL`, atau gunakan parameter:
> ```bash
> sh install.sh --repo https://gitea.domainanda.com/user/alpine-ssh
> ```
> Installer akan otomatis mengunduh static release archive / repository ke `/root/alpine-ssh` dan langsung mengeksekusi instalasi cepat!

---

### 🚀 Opsi 2: Instalasi Folder Lokal (Upload Full Folder - Super Cepat)

Jika Anda meng-upload project full dalam bentuk folder ke VPS (via SFTP, SCP, Git Clone, atau ekstrak ZIP/tar.gz):

```bash
# 1. Masuk ke folder alpine-ssh yang telah diupload
cd /root/alpine-ssh

# 2. Jalankan installer langsung
./install.sh
```

**Kelebihan Mode Folder Lokal:**
- **Deteksi Otomatis & Tanpa Salah**: Script langsung mendeteksi folder project (baik dijalankan dari dalam folder, dari luar folder, atau dengan path berbeda).
- **Deteksi Binary Statis Siap Pakai**: Mendeteksi pre-compiled static binary di `bin/` atau `bin/amd64/`.
- **Eksekusi Instan (5 - 10 Detik)**: Hanya meng-copy binary statis dan template konfigurasi tanpa perlu mengunduh compiler `gcc` atau build toolchain yang memakan waktu dan kuota VPS!
- **Dukungan CLI Flag**: Anda dapat melewati prompt dengan menjalankan:
  ```bash
  ./install.sh --local
  ```

---

## 🛠️ Command-Line Interface (CLI)

You can launch the interactive TUI menu or trigger individual commands directly:

```bash
# Open interactive TUI dashboard
menu
# or
alpinessh

# Account Management
alpinessh add alice SecretPass123 30 2 0    # Create account (user pass days limit_ip quota)
alpinessh trial                            # Generate 1-day trial account
alpinessh del alice                        # Delete account and terminate sessions
alpinessh renew alice 30                   # Extend account by 30 days
alpinessh list                             # List all accounts with status & expiry
alpinessh cek                              # Live monitor active connections & sockets
alpinessh history                          # View disconnected session history & reasons

# System Operations
alpinessh backup                           # Create backup & upload to Telegram Bot
alpinessh restore <file_id_or_path>        # Restore database and accounts
alpinessh domain vpn.example.com           # Change domain & issue SSL certificate
alpinessh cert renew                       # Check & renew SSL certificate
alpinessh limit daemon                     # Start multi-login limiter daemon
alpinessh xp                               # Clean expired accounts
```

---

## 🌐 WebSocket Proxy REST API (`http://127.0.0.1:8081`)

| Endpoint | Method | Description |
| :--- | :--- | :--- |
| `/api/status` | `GET` | Service uptime, total sessions, active connection count |
| `/api/sessions` | `GET` | Complete list of all active sessions, recent history, IPs, usernames, TX/RX |
| `/api/sessions/active` | `GET` | Condensed list of live connected sessions |
| `/api/sessions/history` | `GET` | Circular history buffer of last 100 disconnected sessions with reasons & duration |
| `/api/users` | `GET` | Per-user bandwidth and session aggregations |
| `/api/stats` | `GET` | Bandwidth counters and user counts |
| `/api/disconnect` | `POST/GET` | Disconnect session (`?session=<id>`, `?user=<name>`, `?port=<port>`) |
| `/health` | `GET` | Health check endpoint (`{"success": true}`) |

---

## 📂 Project Structure

```
alpine-ssh/
├── Makefile                     # Build system (make static, make ws, make release)
├── install.sh                   # Alpine Linux bash installer
├── build-release.sh             # Script to build dist/main.zip
├── README.md                    # Documentation
├── conf/                        # System and service configuration templates
│   ├── alpinessh.conf
│   ├── dropbear.conf
│   ├── sshd_config.append
│   └── issue.net
├── cron/                        # Alpine Linux periodic tasks (/etc/periodic/)
│   ├── alpinessh-backup
│   ├── alpinessh-xp
│   └── alpinessh-cert
├── openrc/                      # OpenRC service init scripts (/etc/init.d/)
│   ├── ssh-ws.initd
│   └── alpinessh-limiter.initd
├── include/                     # C Header files
│   ├── alpinessh.h
│   ├── account.h
│   ├── backup.h
│   ├── cert.h
│   ├── db.h
│   ├── domain.h
│   ├── limiter.h
│   ├── menu.h
│   ├── monitor.h
│   ├── telegram.h
│   └── ui.h
├── src/                         # Native C source code
│   ├── main.c
│   ├── menu.c
│   ├── account.c
│   ├── backup.c
│   ├── cert.c
│   ├── db.c
│   ├── domain.c
│   ├── limiter.c
│   ├── monitor.c
│   ├── telegram.c
│   └── ui.c
└── websocket-proxy/             # Go WebSocket Proxy (adapted for Alpine Linux)
    ├── go.mod
    ├── go.sum
    └── ssh-ws.go
```

---

## 📄 License

Licensed under the Apache License 2.0 or MIT License.
EOF
