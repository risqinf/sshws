# Alpine-SSH Webstore & REST API Documentation

Comprehensive REST API reference and developer guide for integrating **Alpine-SSH** with e-commerce platforms, web billing portals (WHMCS, Laravel, WordPress/WooCommerce, Next.js), and automated bot stores.

---

## 1. Overview & Architecture

Alpine-SSH exposes a high-performance REST API embedded natively inside the `ssh-ws` Pure C daemon. All endpoints are proxied through **Nginx & HAProxy SSL (Port 443)** for secure HTTPS communication, or accessible locally via internal loopback (`127.0.0.1:8081`).

### Base URLs
- **Public Production (HTTPS - Port 443)**: `https://<your-vps-domain>/api`
- **Public Production (HTTP - Port 80)**: `http://<your-vps-domain>/api`
- **Internal Loopback (VPS Localhost)**: `http://127.0.0.1:8081/api`

> **Note**: Public communication runs over standard web ports (**80** and **443**) handled by HAProxy and Nginx. The backend daemon runs strictly on internal loopback (`127.0.0.1:8081`) and is completely protected by iptables. Dropbear SSH server is configured on ports **109** and **143**, with OpenSSH on port **22**. Direct SSL and WebSocket SSL are multiplexed on port **443** (plus dedicated port **447** for Direct SSL).

---

## 2. Authentication

External requests from your website or webstore require an API Key.

### Providing the API Key
You can authenticate via any of the following methods:
1. **HTTP Header (Recommended)**:
   ```http
   X-API-Key: your-secret-api-key
   ```
2. **Bearer Token**:
   ```http
   Authorization: Bearer your-secret-api-key
   ```
3. **Query Parameter**:
   ```http
   ?key=your-secret-api-key
   ```

> **Note**: Requests originating directly from `127.0.0.1` or `::1` bypass authentication if no API key has been explicitly configured yet. You can set or generate your API key anytime in the TUI Menu: `menu` -> `Option 10: API Management & Webstore Integration`.

---

## 3. Standard Response Format

All responses are returned in JSON format:

```json
{
  "success": true,
  "message": "Operation completed successfully.",
  "data": { ... }
}
```

### HTTP Status Codes
| Code | Meaning | Description |
|------|---------|-------------|
| `200` | OK | Request succeeded. |
| `400` | Bad Request | Missing required parameters or invalid input format. |
| `401` | Unauthorized | Missing or invalid API key. |
| `404` | Not Found | Target username or session not found. |
| `500` | Server Error | Internal system or database error. |

---

## 4. API Endpoints Reference

### 4.1. System & Server Status
#### `GET /api/status`
Returns daemon health, tunnel uptime, software version, and active session count.

**Response `200 OK`**:
```json
{
  "success": true,
  "status": "online",
  "version": "v1.3.1-Alpine",
  "uptime": "2h 45m 12s",
  "ws_port": 8880,
  "api_port": 8081,
  "total_sessions": 3,
  "active_users": 2
}
```

---

### 4.2. List Live Connected Sessions
#### `GET /api/sessions`
Returns all active WebSocket and Dropbear client connections in real-time, including bandwidth upload/download traffic and connection duration.

**Response `200 OK`**:
```json
{
  "success": true,
  "total": 1,
  "sessions": [
    {
      "id": "0002-010653",
      "username": "client01",
      "remote_ip": "140.213.176.151:60690",
      "proxy_port": 57402,
      "backend_pid": 18365,
      "tx_bytes": 24851251,
      "rx_bytes": 56012480,
      "total_bytes": 80863731,
      "tx_formatted": "23.7 MB",
      "rx_formatted": "53.4 MB",
      "total_formatted": "77.1 MB",
      "duration_seconds": 124,
      "duration_formatted": "2m4s",
      "type": "dropbear"
    }
  ]
}
```

---

### 4.3. List Active Sessions Only
#### `GET /api/sessions/active`
Returns only currently active sessions with count and session array.

**Response `200 OK`**:
```json
{
  "success": true,
  "data": {
    "count": 1,
    "sessions": [
      {
        "id": "0002-010653",
        "username": "client01",
        "real_client_ip": "140.213.176.151",
        "real_client_port": "60690",
        "proxy_port": "57402",
        "ssh_type": "dropbear",
        "pid": 18365,
        "duration": "2m 4s",
        "tx_formatted": "23.7 MB",
        "rx_formatted": "53.4 MB",
        "total_formatted": "77.1 MB"
      }
    ]
  }
}
```

---

### 4.4. Disconnected Session History
#### `GET /api/sessions/history`
Retrieves a circular history buffer of the last 100 disconnected sessions, including exact session duration, total upload/download bandwidth consumed, and disconnect reasons.

**Response `200 OK`**:
```json
{
  "success": true,
  "data": {
    "count": 3,
    "history": [
      {
        "id": "0003-4312d3",
        "username": "client01",
        "real_client_ip": "114.124.201.5",
        "real_client_port": "54870",
        "ssh_type": "dropbear",
        "pid": 19402,
        "connected_at": 1789955400,
        "disconnected_at": 1789956600,
        "duration": "20m 0s",
        "disconnect_reason": "client_closed",
        "tx_bytes": 104857600,
        "rx_bytes": 524288000,
        "total_bytes": 629145600,
        "tx_formatted": "100.0 MB",
        "rx_formatted": "500.0 MB",
        "total_formatted": "600.0 MB"
      }
    ]
  }
}
```

#### Disconnect Reasons
| Reason | Description |
|--------|-------------|
| `client_closed` | The client closed the TCP connection or WebSocket tunnel normally. |
| `idle_timeout` | The connection was closed due to 2 hours of complete inactivity. |
| `detect_timeout` | The inbound connection did not authenticate or transmit SSH traffic within 30 seconds. |
| `admin_disconnect` | Terminated manually by administrator via API (`/api/disconnect`) or limiter daemon. |

---

### 4.5. Disconnect Session
#### `POST /api/sessions/disconnect`
Terminates an active session immediately by session ID or by username.

**Request Body (`application/json`)**:
```json
{
  "username": "client01"
}
```
*Or disconnect specific session ID:*
```json
{
  "session_id": "0002-010653"
}
```

**Response `200 OK`**:
```json
{
  "success": true,
  "message": "Session 0002-010653 disconnected successfully."
}
```

---

### 4.4. List Accounts
#### `GET /api/account/list`
Lists all registered SSH accounts in the SQLite database with their status, limits, and expiration dates.

**Response `200 OK`**:
```json
{
  "success": true,
  "count": 2,
  "accounts": [
    {
      "username": "client01",
      "ip_limit": 2,
      "quota_gb": 50,
      "created_at": "2026-09-20 04:00:00",
      "expired_at": "2026-10-20 04:00:00",
      "status": "active",
      "unlock_at": 0
    },
    {
      "username": "client02",
      "ip_limit": 1,
      "quota_gb": 10,
      "created_at": "2026-09-19 12:00:00",
      "expired_at": "2026-09-20 12:00:00",
      "status": "locked",
      "unlock_at": 1789955400
    }
  ]
}
```

---

### 4.5. Get Account Detail
#### `GET /api/account/detail?username=client01`
Fetches complete profile for an account, including live connection count, bandwidth usage vs limit, and lock state.

**Response `200 OK`**:
```json
{
  "success": true,
  "data": {
    "username": "client01",
    "status": "active",
    "ip_limit": 2,
    "active_ips": 1,
    "quota_gb": 50,
    "usage_tx_bytes": 104857600,
    "usage_rx_bytes": 419430400,
    "usage_total_bytes": 524288000,
    "usage_formatted": "500.0 MB",
    "created_at": "2026-09-20 04:00:00",
    "expired_at": "2026-10-20 04:00:00",
    "days_remaining": 30,
    "unlock_at": 0
  }
}
```

---

### 4.6. Create SSH Account
#### `POST /api/account/create`
Creates a new Alpine Linux SSH user with encrypted password, adds it to the SQLite database, and returns full connection settings.

**Request Body (`application/json`)**:
```json
{
  "username": "buyer_123",
  "password": "StrongPassword99!",
  "days": 30,
  "limit_ip": 2,
  "quota_gb": 100
}
```
*Field parameters:*
- `username` (string, required): Alphanumeric, underscores, hyphens (max 32 chars).
- `password` (string, required): Account password.
- `days` (integer, optional, default `30`): Expiration period in days.
- `limit_ip` (integer, optional, default `2`): Allowed simultaneous IPs.
- `quota_gb` (integer, optional, default `0`): Bandwidth quota in GB (`0` = Unlimited).

**Response `200 OK`**:
```json
{
  "success": true,
  "message": "SSH Account buyer_123 created successfully.",
  "data": {
    "username": "buyer_123",
    "password": "StrongPassword99!",
    "domain": "vpn.yourdomain.com",
    "server_ip": "203.0.113.10",
    "limit_ip": 2,
    "quota_gb": 100,
    "expired_date": "2026-10-20 04:15:00",
    "ports": {
      "openssh": 22,
      "dropbear": [109, 143],
      "ws_http": [80, 8880],
      "ws_ssl": 443,
      "udpgw": 7300
    },
    "payload_ws": "GET / HTTP/1.1[crlf]Host: vpn.yourdomain.com[crlf]Upgrade: websocket[crlf][crlf]",
    "config_http_custom": "vpn.yourdomain.com:80@buyer_123:StrongPassword99!"
  }
}
```

---

### 4.7. Renew Account
#### `POST /api/account/renew`
Extends the expiration of an existing account.

**Request Body (`application/json`)**:
```json
{
  "username": "buyer_123",
  "days": 30
}
```

**Response `200 OK`**:
```json
{
  "success": true,
  "message": "Account buyer_123 renewed for 30 days.",
  "new_expired_date": "2026-11-19 04:15:00"
}
```

---

### 4.8. Lock Account
#### `POST /api/account/lock`
Locks an account and terminates any running sessions. You can specify a cooldown duration in seconds (defaults to `300` seconds / 5 minutes), after which the limiter daemon automatically unlocks it.

**Request Body (`application/json`)**:
```json
{
  "username": "buyer_123",
  "duration": 300
}
```

**Response `200 OK`**:
```json
{
  "success": true,
  "message": "Account buyer_123 locked for 300 seconds."
}
```

---

### 4.9. Unlock Account
#### `POST /api/account/unlock`
Immediately unlocks a previously locked account.

**Request Body (`application/json`)**:
```json
{
  "username": "buyer_123"
}
```

**Response `200 OK`**:
```json
{
  "success": true,
  "message": "Account buyer_123 unlocked successfully."
}
```

---

### 4.10. Delete Account
#### `POST /api/account/delete`
Permanently deletes the account from the OS (`deluser`) and SQLite database.

**Request Body (`application/json`)**:
```json
{
  "username": "buyer_123"
}
```

**Response `200 OK`**:
```json
{
  "success": true,
  "message": "Account buyer_123 deleted successfully."
}
```

---

## 5. Ready-to-Use Code Examples

### 5.1. PHP (cURL / WHMCS / WordPress)
```php
<?php
class AlpineSSHClient {
    private $baseUrl;
    private $apiKey;

    public function __construct($baseUrl, $apiKey) {
        $this->baseUrl = rtrim($baseUrl, '/');
        $this->apiKey = $apiKey;
    }

    private function request($method, $endpoint, $data = null) {
        $ch = curl_init($this->baseUrl . $endpoint);
        curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
        curl_setopt($ch, CURLOPT_CUSTOMREQUEST, $method);
        curl_setopt($ch, CURLOPT_HTTPHEADER, [
            'Content-Type: application/json',
            'X-API-Key: ' . $this->apiKey
        ]);
        curl_setopt($ch, CURLOPT_TIMEOUT, 15);

        if ($data && in_array($method, ['POST', 'PUT', 'PATCH'])) {
            curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode($data));
        }

        $res = curl_exec($ch);
        $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
        curl_close($ch);

        return [
            'status' => $httpCode,
            'body' => json_decode($res, true)
        ];
    }

    public function createAccount($username, $password, $days = 30, $limitIp = 2, $quotaGb = 0) {
        return $this->request('POST', '/api/account/create', [
            'username' => $username,
            'password' => $password,
            'days'     => (int)$days,
            'limit_ip' => (int)$limitIp,
            'quota_gb' => (int)$quotaGb
        ]);
    }

    public function renewAccount($username, $days = 30) {
        return $this->request('POST', '/api/account/renew', [
            'username' => $username,
            'days'     => (int)$days
        ]);
    }

    public function deleteAccount($username) {
        return $this->request('POST', '/api/account/delete', [
            'username' => $username
        ]);
    }

    public function getSessions() {
        return $this->request('GET', '/api/sessions');
    }
}

// Example Usage:
$client = new AlpineSSHClient('https://vpn.yourdomain.com', 'your-secret-api-key');
$result = $client->createAccount('order_7849', 'SecurePass123!', 30, 2, 50);

if ($result['status'] === 200 && $result['body']['success']) {
    echo "Account created! Expire at: " . $result['body']['data']['expired_date'] . "\n";
    echo "Payload: " . $result['body']['data']['payload_ws'] . "\n";
} else {
    echo "Failed: " . ($result['body']['error'] ?? 'Unknown error') . "\n";
}
?>
```

---

### 5.2. Node.js / TypeScript (Axios / Fetch)
```javascript
const axios = require('axios');

const API_BASE = 'https://vpn.yourdomain.com/api';
const API_KEY = 'your-secret-api-key';

const client = axios.create({
  baseURL: API_BASE,
  headers: {
    'Content-Type': 'application/json',
    'X-API-Key': API_KEY
  },
  timeout: 10000
});

async function createBuyerAccount(username, password, days = 30) {
  try {
    const res = await client.post('/account/create', {
      username,
      password,
      days,
      limit_ip: 2,
      quota_gb: 100
    });
    console.log('Account Created:', res.data);
    return res.data;
  } catch (err) {
    console.error('Error creating account:', err.response?.data || err.message);
    throw err;
  }
}

async function listLiveSessions() {
  const res = await client.get('/sessions');
  console.log('Active Sessions:', res.data.sessions);
}

// createBuyerAccount('testuser99', 'Password123#');
```

---

### 5.3. Python (Requests)
```python
import requests

BASE_URL = "https://vpn.yourdomain.com/api"
API_KEY = "your-secret-api-key"

headers = {
    "Content-Type": "application/json",
    "X-API-Key": API_KEY
}

def create_account(username, password, days=30, limit_ip=2, quota_gb=0):
    payload = {
        "username": username,
        "password": password,
        "days": days,
        "limit_ip": limit_ip,
        "quota_gb": quota_gb
    }
    r = requests.post(f"{BASE_URL}/account/create", json=payload, headers=headers)
    return r.status_code, r.json()

def delete_account(username):
    r = requests.post(f"{BASE_URL}/account/delete", json={"username": username}, headers=headers)
    return r.status_code, r.json()

# Example:
# code, res = create_account("py_buyer", "Secret123!", days=30)
# print(code, res)
```

---

### 5.4. cURL (Bash Command Line)
```bash
# 1. Check Server Status
curl -s -H "X-API-Key: your-secret-api-key" https://vpn.yourdomain.com/api/status

# 2. Create an Account
curl -s -X POST https://vpn.yourdomain.com/api/account/create \
  -H "Content-Type: application/json" \
  -H "X-API-Key: your-secret-api-key" \
  -d '{"username":"curl_user","password":"mypassword","days":30,"limit_ip":2,"quota_gb":50}'

# 3. Check Live Connected Sessions
curl -s -H "X-API-Key: your-secret-api-key" https://vpn.yourdomain.com/api/sessions

# 4. Renew Account
curl -s -X POST https://vpn.yourdomain.com/api/account/renew \
  -H "Content-Type: application/json" \
  -H "X-API-Key: your-secret-api-key" \
  -d '{"username":"curl_user","days":30}'
```

---

---

## 6. Client Configuration Reference

When presenting connection details to customers on your store or mobile application:

| Parameter | Recommended Value | Protocol |
|-----------|-------------------|----------|
| **Host / SNI** | Your VPS Domain (e.g. `vpn.yourdomain.com`) | All |
| **Server IP** | VPS Public IPv4 | All |
| **OpenSSH Port** | `22` | Direct Raw SSH |
| **Dropbear Ports** | `109, 143` | Direct Raw SSH |
| **SSH WS (HTTP)** | `80, 8880` | WebSocket HTTP (Bug Host / CDN) |
| **SSH WS (SSL/TLS)** | `443` | WebSocket HTTPS (Cloudflare / SNI) |
| **SSH Direct (SSL/TLS)** | `443, 447` | Direct SSH encapsulated in TLS |
| **BadVPN UDPGW** | `7300` | UDP Gateway (WhatsApp Calls, Gaming) |
| **WS Path** | `/ssh` (or `/`) | WebSocket HTTP/HTTPS |
| **Payload WS HTTP** | `GET /ssh HTTP/1.1[crlf]Host: [host][crlf]Upgrade: websocket[crlf][crlf]` | HTTP Custom / Injector |
| **Payload WS SSL** | `GET /ssh HTTP/1.1[crlf]Host: [host][crlf]Upgrade: websocket[crlf][crlf]` | SNI: `[host]` |

---

## 7. Webhook & Payment Gateway Integration Example

Automate account creation upon successful user payment (e.g., Midtrans, Tripay, Xendit, Duitku, PayPal, or Stripe):

### Example: PHP Payment Callback Handler (`callback.php`)
```php
<?php
// Secret webhook token & Alpine-SSH credentials
$apiSecret = 'your-payment-webhook-secret';
$alpineApiUrl = 'https://vpn.yourdomain.com/api';
$alpineApiKey = 'your-secret-api-key';

// Read raw webhook payload
$rawPayload = file_get_contents('php://input');
$data = json_decode($rawPayload, true);

// Verify payment status (e.g., status is PAID / SETTLED)
if ($data && ($data['status'] === 'PAID' || $data['status'] === 'settlement')) {
    $orderId = $data['order_id'];
    $buyerUser = 'usr_' . substr(md5($orderId), 0, 8);
    $buyerPass = bin2hex(random_bytes(6));
    $durationDays = isset($data['duration_days']) ? (int)$data['duration_days'] : 30;

    // Call Alpine-SSH API to create account
    $ch = curl_init($alpineApiUrl . '/account/create');
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
    curl_setopt($ch, CURLOPT_POST, true);
    curl_setopt($ch, CURLOPT_HTTPHEADER, [
        'Content-Type: application/json',
        'X-API-Key: ' . $alpineApiKey
    ]);
    curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode([
        'username' => $buyerUser,
        'password' => $buyerPass,
        'days'     => $durationDays,
        'limit_ip' => 2,
        'quota_gb' => 0 // Unlimited
    ]));

    $response = curl_exec($ch);
    $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
    curl_close($ch);

    $resData = json_decode($response, true);
    if ($httpCode === 200 && $resData['success']) {
        // Send account credentials to buyer via WhatsApp / Email
        // sendAccountNotification($data['customer_email'], $resData['data']);
        http_response_code(200);
        echo json_encode(['success' => true, 'message' => 'Account provisioned successfully.']);
        exit;
    }
}

http_response_code(400);
echo json_encode(['success' => false, 'message' => 'Invalid payment callback.']);
?>
```

---

## 7. Multi Payload, Dual Payload & Wild HTTP Injector Guide

Alpine-SSH features an advanced Pure C WebSocket proxy (`ssh-ws`) engine integrated with HAProxy L7 multiplexing that supports **Multi Payload**, **Dual Payload**, **Wild HTTP Methods**, **Wild HTTP Versions**, and **Arbitrary Paths** with zero configuration limits.

### 7.1 Architecture & Bypass Mechanism
Traditional WebSocket setups pass all incoming HTTP traffic through Nginx. When clients use injector tricks like non-standard HTTP versions (e.g. `HTTP/69`, `HTTP/99`) or pipelined multiple requests, Nginx strictly rejects them with `400 Bad Request` or `505 HTTP Version Not Supported`.

In **Alpine-SSH**:
- **HAProxy L7** directly inspects traffic in raw TCP mode. Only ACME challenges (`/.well-known/acme-challenge/`) and web API calls (`/api/`) route to Nginx.
- Raw Direct SSH (`SSH-`) routes directly to Dropbear (:109).
- **All other HTTP and WebSocket traffic** (Port 80 plain, and Port 443/447 TLS decrypted) routes directly to `ssh-ws` (:8880) with PROXY protocol v1.
- `ssh-ws` absorbs the HTTP probe and upgrade headers, responds with RFC-compliant `101 Switching Protocols` (or interactive `200 OK` probe response), and immediately bridges raw traffic to Dropbear (:109).

### 7.2 Supported Features
| Feature | Capabilities |
| :--- | :--- |
| **Multi / Dual Payload** | Supports chained requests in 1 buffer (e.g. Probe + Upgrade back-to-back) and interactive split requests (`[split]`). |
| **Wild HTTP Methods** | `HEAD`, `GET`, `POST`, `OPTIONS`, `PUT`, `DELETE`, `PATCH`, `TRACE`, `CONNECT`, or any custom method string (`PROPFIND`, `CUSTOM`, etc.). |
| **Wild HTTP Versions** | `HTTP/1.1`, `HTTP/1.0`, `HTTP/2.0`, `HTTP/69`, `HTTP/99`, `HTTP/0.9`, or arbitrary version tokens. |
| **Wild Custom Paths** | `/`, `/ssh`, `/ws`, `/cgi`, `/cdn-cgi/trace`, or any arbitrary URI. |
| **Evasion Header Tolerance** | Completely immune to integer overflows (`Content-Length: 9999999999999999999999`), non-numeric strings (`Content-Length: @Rerechan02`), typo headers (`Content-Legth: ...`), and non-standard spacing (`Upgrade : websocket`, `Upgrade:websocket`). |
| **Zero Body Stall Guarantee** | The proxy terminates HTTP header parsing strictly at `\r\n\r\n` or `\n\n` without buffering according to `Content-Length`, forwarding any trailing bytes directly to Dropbear. |
| **Maximum Throughput Engine** | `TCP_NODELAY = 1`, `TCP_QUICKACK = 1` (zero delayed ACK), `SO_RCVBUF` & `SO_SNDBUF` set to 128 KB, 64 KB bidirectional copy buffers, and aggressive dead-socket cleanup (`TCP_KEEPIDLE = 30s`, `TCP_KEEPINTVL = 5s`, `TCP_KEEPCNT = 3`). |
| **Real-Time Auditing Events** | Real-time structured logs to stdout and `/var/log/ssh-ws.log`: `TCP-CONNECT`, `WS-UPGRADE`, `USER-CONNECT` (with auth username, PID, IP, port), `USER-DISCONNECT` (with duration, upload, download, total bytes, disconnect reason), and `TCP-DISCONNECT`. |
| **Real IP Preservation** | Native PROXY protocol v1 parser extracts the real client IP and port from HAProxy `send-proxy`. |

---

### 7.3 Client Configuration Examples (HTTP Custom / HTTP Injector / NetMod)

#### Example 1: Classic Dual Payload (Chained Single-Buffer)
Sends an initial probe to the ISP bug host, immediately followed by a WebSocket Upgrade using custom method `PATCH` and non-standard `HTTP/69`:

```http
HEAD / HTTP/1.1[crlf]Host: bug.zoom.us[crlf][crlf]PATCH /cdn-cgi/trace HTTP/69[crlf]Host: [host][crlf]Upgrade: websocket[crlf]Connection: Upgrade[crlf]Sec-WebSocket-Key: [ua][crlf][crlf]
```

#### Example 2: Interactive Split Payload (`[split]`)
Sends an initial `HEAD` probe. Alpine-SSH acknowledges with `HTTP/1.1 200 OK`, allowing the zero-rating filter to pass. Once received, the injector sends Payload 2 (`GET /cgi HTTP/99`), which Alpine-SSH upgrades with `101 Switching Protocols`:

```http
HEAD / HTTP/1.1[crlf]Host: bug.zoom.us[crlf][crlf][split]GET /cgi HTTP/99[crlf]Host: [host][crlf]Upgrade: websocket[crlf]Connection: Upgrade[crlf]Sec-WebSocket-Key: [ua][crlf][crlf]
```

#### Example 3: Cloudflare CDN Trace Payload
Bypasses Cloudflare edge firewalls by targeting the CDN trace diagnostics endpoint:

```http
GET /cdn-cgi/trace HTTP/1.1[crlf]Host: [host][crlf]Upgrade: websocket[crlf]Connection: Upgrade[crlf]Sec-WebSocket-Key: [ua][crlf][crlf]
```

#### Example 4: Direct SSL / TLS with SNI Bug
For Direct SSL clients (HTTP Custom Direct SSL / Stunnel):
- **Server / Host**: Your VPS IP or Domain
- **Port**: `443` or `447`
- **SNI**: Bug host (e.g. `m.youtube.com`, `v.whatsapp.net`, `zoom.us`)
- Direct SSH packets (`SSH-2.0...`) are instantly detected by HAProxy and routed to Dropbear (:109).
