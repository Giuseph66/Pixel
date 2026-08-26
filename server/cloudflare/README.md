# Cloudflare DNS import

Import `pixel-signal.zone` in **DNS > Records > Import**. It creates:

```text
pixel-signal.neurelix.com.br -> existing Cloudflare Tunnel
```

After the import, configure the existing `neurelix-tunel` public hostname to
forward `pixel-signal.neurelix.com.br` to `http://signal:8787` when using the
Docker `cloudflared` service, or to `http://127.0.0.1:8787` when the host's
cloudflared process runs directly.

Do not create `turn.pixel.neurelix.com.br` from this import. TURN needs an `A`
record with the machine's real public WAN IP and must stay **DNS only** (grey
cloud). Cloudflare Tunnel/proxy does not route its UDP relay traffic.
