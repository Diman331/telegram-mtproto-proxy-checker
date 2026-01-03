# Telegram MTProto Proxy Checker

A Node.js CLI tool that verifies Telegram MTProto proxies by actually communicating with Telegram servers using the official TDLib API.

## Features

- ✅ **Real Verification**: Verifies proxies by actually communicating with Telegram servers, not just TCP connections
- ✅ **Uses TDLib**: Official Telegram Database Library API (`addProxy` and `pingProxy` methods)
- ✅ **No Authorization Required**: Works before login - no phone number or bot token needed
- ✅ **Multiple URL Formats**: Supports both `tg://proxy?` and `https://t.me/proxy?` formats
- ✅ **Smart Secret Handling**: Auto-detects and converts hex/base64 secrets
- ✅ **Detailed Error Messages**: Shows specific failure reasons (connection refused, timeout, invalid secret, etc.)
- ✅ **Scriptable**: Proper exit codes for automation
- ✅ **Cross-Platform**: Works on Windows, Linux, and macOS

## Installation

### Clone from GitHub

```bash
git clone https://github.com/AmirTahaMim/telegram-mtproto-proxy-checker.git
cd telegram-mtproto-proxy-checker
npm install
```

### Install Dependencies

```bash
npm install
```

This will install:
- `tdl` - Node.js wrapper for TDLib
- `tdl-tdlib-addon` - TDLib native bindings
- `prebuilt-tdlib` - Pre-built TDLib binaries for your platform

## Usage

### Basic Usage

**Command line argument:**
```bash
node index.js "https://t.me/proxy?server=IP&port=PORT&secret=SECRET"
```

**Using tg:// format:**
```bash
node index.js "tg://proxy?server=IP&port=PORT&secret=SECRET"
```

**From stdin:**
```bash
# Linux/macOS
echo "https://t.me/proxy?server=IP&port=PORT&secret=SECRET" | node index.js

# Windows PowerShell
"https://t.me/proxy?server=IP&port=PORT&secret=SECRET" | node index.js
```

**Debug mode (detailed output):**
```bash
node index.js --debug "https://t.me/proxy?server=IP&port=PORT&secret=SECRET"
```

## Output

### Success
```
OK
```

### Failure with Detailed Error
```
NO: CONNECTION_REFUSED: Proxy server refused the connection (server might be down or port is closed)
NO: DNS_ERROR: Cannot resolve server hostname to IP address
NO: TIMEOUT: Proxy did not respond within 15 seconds
NO: Response hash mismatch
NO: INVALID_SECRET: Secret format is invalid or incorrect
```

### Invalid Secret Format
```
INVALID_SECRET
```

## Exit Codes

- `0` - Proxy verification successful (OK)
- `1` - Invalid secret format (INVALID_SECRET)
- `2` - Proxy verification failed (NO with detailed error)

## Examples

### Example 1: Working Proxy
```bash
$ node index.js "https://t.me/proxy?server=163.5.31.10&port=8443&secret=EERighJJvXrFGRMCIMJdCQRueWVrdGFuZXQuY29tZmFyYWthdi5jb212YW4ubmFqdmEuY29tAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
OK
```

### Example 2: Failed Proxy
```bash
$ node index.js "https://t.me/proxy?server=invalid.example.com&port=443&secret=abcd1234"
NO: DNS_ERROR: Cannot resolve server hostname to IP address
```

### Example 3: Debug Mode
```bash
$ node index.js --debug "https://t.me/proxy?server=example.com&port=443&secret=secret123"
[DEBUG] Parsed URL:
[DEBUG]   Server: example.com
[DEBUG]   Port: 443
[DEBUG]   Secret (raw): secret123...
[DEBUG]   Secret format: base64
[DEBUG] Connected to TDLib
[DEBUG] Server: example.com
[DEBUG] Port: 443
[DEBUG] Secret (hex, first 32 chars): b2b9b2b9b2b9b2b9b2b9b2b9b2b9b2b9...
[DEBUG] Secret length: 9 bytes
NO: CONNECTION_REFUSED: Proxy server refused the connection
```

## How It Works

1. **URL Parsing**: Extracts `server`, `port`, and `secret` from the proxy URL
2. **Secret Normalization**:
   - If secret contains only hex characters `[0-9a-fA-F]`, treats it as hex
   - Otherwise, treats it as URL-safe Base64
   - Normalizes Base64: `-` → `+`, `_` → `/`
   - Adds padding (`=`) to make length a multiple of 4
   - Decodes to raw bytes and converts to lowercase hex string
3. **TDLib Client**: Creates a TDLib client (no authorization required)
4. **Add Proxy**: Calls `addProxy` with the normalized secret
5. **Ping Proxy**: Calls `pingProxy` to verify actual connectivity to Telegram servers
6. **Result**: Returns success or detailed error message

## Error Messages Explained

| Error Message | Meaning |
|--------------|---------|
| `CONNECTION_REFUSED` | Proxy server is not accepting connections (down or firewall blocking) |
| `DNS_ERROR` | Cannot resolve the server hostname |
| `TIMEOUT` | Proxy did not respond within 15 seconds |
| `Response hash mismatch` | Proxy is reachable but secret is incorrect or proxy misconfigured |
| `INVALID_SECRET` | Secret format cannot be decoded (invalid hex or base64) |
| `INVALID_PORT` | Port number is invalid or out of range |
| `INVALID_SERVER` | Server address is invalid |

## Requirements

- **Node.js** ≥ 18
- **Platform**: Windows, Linux, or macOS (TDLib binaries are platform-specific)
- **Internet Connection**: Required for initial TDLib download and proxy verification

## Technical Details

- Uses TDLib's `addProxy` and `pingProxy` methods
- Proxy verification works **before authorization** (no login required)
- Timeout is set to 15 seconds for proxy ping
- Supports long Fake-TLS Base64 secrets
- Automatically handles both hex and base64 secret formats
- TDLib binaries are automatically downloaded via `prebuilt-tdlib` package

## Troubleshooting

### "Dynamic Loading Error: Win32 error 126"
- Ensure `prebuilt-tdlib` package is installed: `npm install prebuilt-tdlib`
- On Windows, the `tdjson.dll` will be automatically downloaded

### "Cannot find module 'tdl'"
- Run `npm install` to install all dependencies

### Proxy verification times out
- Check if the proxy server is accessible
- Verify the server IP/hostname and port are correct
- Some proxies may have longer response times - this is normal

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## License

MIT License - see [LICENSE](LICENSE) file for details


