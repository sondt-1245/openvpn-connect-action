# OpenVPN Connect - GitHub Composite Action

A GitHub Action that establishes an OpenVPN connection using a composite action. It installs OpenVPN, writes configuration files, connects in daemon mode, and verifies the tunnel is up.

Inspired by [kota65535/github-openvpn-connect-action](https://github.com/kota65535/github-openvpn-connect-action) — reimplemented as a pure composite action using shell scripts.

Since composite actions do not support native `post` steps, this action uses a **mode** input to handle both connecting and disconnecting. Use `mode: disconnect` with `if: always()` to ensure cleanup runs even if prior steps fail.

## Inputs

| Input             | Required | Default    | Description                                                      |
|-------------------|----------|------------|------------------------------------------------------------------|
| `config`          | Yes      |            | OpenVPN config file content (`.ovpn` file contents)              |
| `username`        | No       | `""`       | Username for `auth-user-pass` authentication                     |
| `password`        | No       | `""`       | Password for `auth-user-pass` authentication                     |
| `client_key`      | No       | `""`       | Client private key content                                       |
| `tls_auth_key`    | No       | `""`       | Pre-shared group key for TLS Auth                                |
| `tls_crypt_key`   | No       | `""`       | Pre-shared group key for TLS Crypt                               |
| `tls_crypt_v2_key`| No       | `""`       | Per-client key for TLS Crypt V2                                  |
| `echo_config`     | No       | `"true"`   | Print the OpenVPN config for debugging (`true` / `false`)        |
| `ping_url`        | No       | `""`       | IP/hostname to ping after connection to verify VPN is working    |
| `mode`            | No       | `"connect"`| `connect` to establish VPN, `disconnect` to tear it down         |

## Outputs

| Output   | Description                              |
|----------|------------------------------------------|
| `status` | VPN connection status (`true` / `false`) |

## How It Works

The action modifies the config file in-place (same approach as [kota65535/github-openvpn-connect-action](https://github.com/kota65535/github-openvpn-connect-action)):

1. **Install** — Installs `openvpn` and `openvpn-systemd-resolved` on the runner.
2. **Configure** — Writes the `.ovpn` config to `/tmp/vpn.ovpn`, then **appends directives** for any optional inputs (username/password, client key, TLS keys) pointing to separate temp files.
3. **Connect** — Starts OpenVPN as a background daemon.
4. **Verify** — Watches the log for `Initialization Sequence Completed` (up to 30 seconds), then optionally pings the target host.
5. **Disconnect** — Kills the OpenVPN process by PID and removes all temporary files.

## Usage

### Basic: username & password auth

```yaml
steps:
  - name: Checkout
    uses: actions/checkout@v4

  - name: Connect VPN
    uses: sondt-1245/openvpn-connect-action@v1
    with:
      config: ${{ secrets.OPENVPN_CONFIG_FILE }}
      username: ${{ secrets.OVPN_USERNAME }}
      password: ${{ secrets.OVPN_PASSWORD }}
      ping_url: "10.0.0.1"

  - name: Do work over VPN
    run: curl http://internal-service.local

  - name: Disconnect VPN
    if: always()
    uses: sondt-1245/openvpn-connect-action@v1
    with:
      mode: disconnect
```

### Config with inline keys (no extra inputs needed)

If your `.ovpn` file already contains `<ca>`, `<tls-auth>`, `auth-user-pass`, etc. inline, just pass the config — no extra inputs required:

```yaml
steps:
  - name: Checkout
    uses: actions/checkout@v4

  - name: Connect VPN
    uses: sondt-1245/openvpn-connect-action@v1
    with:
      config: ${{ secrets.OPENVPN_CONFIG_FILE }}
      ping_url: ${{ secrets.PRIVATE_SERVER_IP }}

  - name: Disconnect VPN
    if: always()
    uses: sondt-1245/openvpn-connect-action@v1
    with:
      mode: disconnect
```

### Client certificate + TLS auth

```yaml
steps:
  - name: Checkout
    uses: actions/checkout@v4

  - name: Connect VPN
    uses: sondt-1245/openvpn-connect-action@v1
    with:
      config: ${{ secrets.OPENVPN_CONFIG_FILE }}
      client_key: ${{ secrets.OVPN_CLIENT_KEY }}
      tls_auth_key: ${{ secrets.OVPN_TLS_AUTH_KEY }}
      ping_url: ${{ secrets.PRIVATE_SERVER_IP }}

  - name: Deploy
    run: ./deploy.sh

  - name: Disconnect VPN
    if: always()
    uses: sondt-1245/openvpn-connect-action@v1
    with:
      mode: disconnect
```

## Secrets Setup

Store the following as [GitHub encrypted secrets](https://docs.github.com/en/actions/security-guides/using-secrets-in-github-actions):

| Secret                  | Description                                                  |
|-------------------------|--------------------------------------------------------------|
| `OPENVPN_CONFIG_FILE`   | Full contents of your `.ovpn` configuration file             |
| `OVPN_USERNAME`         | OpenVPN username (if using auth-user-pass)                   |
| `OVPN_PASSWORD`         | OpenVPN password (if using auth-user-pass)                   |
| `OVPN_CLIENT_KEY`       | Client private key (if using certificate auth)               |
| `OVPN_TLS_AUTH_KEY`     | TLS auth key (if your server requires `--tls-auth`)          |
| `PRIVATE_SERVER_IP`     | IP of a host behind the VPN to verify connectivity           |

## Requirements

- Runs on `ubuntu-latest` (or any Debian-based runner with `apt-get`).
- The runner must have `sudo` access (default on GitHub-hosted runners).

## License

MIT
