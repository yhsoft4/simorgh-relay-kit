#!/usr/bin/env python3
"""Throughput test through the tunnel, one direction at a time (no packages needed).
  receiver:  python3 bw.py recv 10.10.0.1 5099      (run first, on the end that receives)
  sender:    python3 bw.py send 10.10.0.1 5099 30   (30 MB; run on the other end)
Do both directions. Healthy example: ~140 Mbit/s each way, no errors."""
import socket, sys, time

mode, host, port = sys.argv[1], sys.argv[2], int(sys.argv[3])
if mode == "recv":
    s = socket.socket(); s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    s.bind((host, port)); s.listen(1); s.settimeout(30)
    c, _ = s.accept(); c.settimeout(20); n, t0 = 0, time.time()
    try:
        while (d := c.recv(65536)):
            n += len(d)
    except Exception as e:  # noqa: BLE001 report any stall instead of hanging
        print("recv stopped:", type(e).__name__)
    dt = max(time.time() - t0, 1e-6)
    print("RECV %.1f MB in %.1fs = %.1f Mbit/s" % (n / 1e6, dt, n * 8 / dt / 1e6))
else:
    mb = int(sys.argv[4]) if len(sys.argv) > 4 else 30
    c = socket.create_connection((host, port), timeout=10); c.settimeout(20)
    buf, n, t0 = b"x" * 65536, 0, time.time()
    try:
        while n < mb * 1_000_000:
            c.sendall(buf); n += len(buf)
    except Exception as e:  # noqa: BLE001
        print("send stopped:", type(e).__name__)
    c.close(); dt = max(time.time() - t0, 1e-6)
    print("SENT %.1f MB in %.1fs = %.1f Mbit/s" % (n / 1e6, dt, n * 8 / dt / 1e6))
