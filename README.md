# Simorgh Relay Kit

**English** · [فارسی](README_FA.md)

A field-tested setup kit for an **Iran → abroad relay**: users connect to a server in Iran, and a
[BackPack](https://github.com/AminMGMT/BackPack) Direct PCK layer-3 tunnel carries their traffic to your
V2Ray/Xray server abroad. It contains sanitized config templates, health-check scripts and the lessons from a
real deployment.

> Based on BackPack by Amin Mohammadi (AminMGMT): https://github.com/AminMGMT/BackPack
> This kit does **not** contain, copy or modify BackPack. You install the official, unmodified release.
> "BackPack" is its author's name and mark; this kit has its own name and is not affiliated with it.

## How it works

```
user in Iran ──► Iran server (public IP, forwarded ports) ──[ bp0 tunnel, Iran DIALS OUT ]──► kharej server ──► V2Ray/Xray
```

- The **Iran side dials out** to the kharej server (`mode = "dial"`), the kharej side listens on one port (9000).
  Outbound from Iran is open, so the tunnel survives even when the Iran IP is unreachable **from abroad**.
- Tunnel addresses: Iran `10.10.0.1`, kharej `10.10.0.2` (a /30 on interface `bp0`).
- Users connect to the **Iran IP** on the forwarded ports; each port goes to the same port on kharej.

## One-command install (this relay only)

```bash
# 1) kharej server (abroad): installs official BackPack, writes the config + service, prints the Iran command
sudo bash scripts/install-relay.sh kharej

# 2) Iran server: paste the token from step 1 (do not post it anywhere)
sudo TUNNEL_TOKEN='...' bash scripts/install-relay.sh iran KHAREJ_IP --ports "80,8080,8443,2053"

bash scripts/install-relay.sh status        # service, bp0 and ping of the other end
```

It sets up exactly one thing: the Direct PCK layer-3 relay above. Use `--dry-run` to see the config without
installing; `uninstall` removes only this relay's config and service. It refuses to run if another BackPack
`l3` tunnel is active on `bp0`. For a server that already has a tunnel, keep using BackPack's own menu.

## Setup (about 20 minutes)

1. Install BackPack from its official repository on both servers (follow its README, unmodified).
2. In its menu create a **Direct PCK layer-3** tunnel: kharej = listen on `:9000`, Iran = dial to `KHAREJ_IP:9000`.
   Add your ports in the wizard. Compare the result with [`configs/`](configs/); values should look the same.
3. Run the checks below. Install the monitor if you want a log: `scripts/install-monitor.sh IRAN_IP PORT...` (as root on the kharej server).

## Verify (do all three, they take two minutes)

| Check | Command | Healthy |
|---|---|---|
| Tunnel + MTU | `scripts/mtu-check.sh 10.10.0.1` (on kharej) | all payload sizes ok |
| Throughput, both ways | `scripts/bw.py recv ...` / `send ...` (see header) | ~100+ Mbit/s each way, no errors |
| From inside Iran | `scripts/check-ports.sh IRAN_IP PORT...` then a real client | ports open, real delay works |

## Known behaviours (things that look like faults but are not)

- **No ping from abroad to the Iran IP.** If check-host.net shows Iran nodes 4/4 and every foreign node 0/4, the
  Iran IP is closed to international inbound traffic. The relay does not need it: the tunnel is outbound from Iran.
  Judge health by `tunnel_ping`, the service state and a real client test from Iran, not by pings from abroad.
- **Ping works but the client's real delay fails.** First suspect the SNI, not the tunnel: some Reality/TLS names
  get no reply on Iranian networks while others complete the handshake on the same port. Test with
  `scripts/sni-probe.sh IRAN_IP PORT name1 name2 ...` from a machine inside Iran, then change the config's SNI.
- **Mobile operators differ.** Test from the operator your users are on before blaming the server.

## Files

- `configs/iran-dial.toml.example`, `configs/kharej-listen.toml.example`: the values of a working pair
  (the secret line BackPack generates is intentionally absent; never commit it).
- `scripts/install-relay.sh` (installer for this relay), `scripts/monitor.sh`, `scripts/install-monitor.sh IRAN_IP PORT...` (as root on the kharej server): 5-minute reachability log + systemd timer.
  Note: its `public_ping` and `ports` fields are tested from the kharej server, so they fail when the Iran IP is
  closed from abroad even though users are fine.
- `scripts/bw.py`, `scripts/mtu-check.sh`, `scripts/sni-probe.sh`, `scripts/check-ports.sh`: the checks above.

## Support

If this saved you time, you can support the work with TRX / USDT on the TRON network:

```
TYT5gy4y1UKvU55sMS6u5YeHnsA7raYuo1
```

License: MIT for this kit's docs and scripts (see `LICENSE`); BackPack keeps its own license (AGPL-3.0 with its
additional terms). See `NOTICE.md`.
