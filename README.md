# APITWO

[查看中文文档 (README_ZH.md)](README_ZH.md)

## Project Introduction

**APITWO** is a high-performance, lightweight API rate-limiting gateway built with **OpenResty**, **Lua**, and **Redis**. It supports flexible multi-tier rate limiting (per-minute, per-hour, per-day) and is ideal for microservices, public APIs, and any scenario that demands robust traffic control.

## Features

- Multi-level rate limiting: per day / hour / minute
- Customizable limit thresholds
- JWT user-based limiting ready (plug-in by rewriting `get_client_key()`)
- Hot reload of Lua and Nginx configuration
- One-click Docker deployment 

## Architecture Diagram

```
+----------+     +--------------+     +----------+
|  Client  | --> |  OpenResty   | --> |  Backend |
+----------+     | (limit.lua)  |     +----------+
                 |   Redis      |
                 +--------------+
```

## Directory Structure

```
├── docker-compose.yml   # Redis + OpenResty services
├── nginx.conf           # Main OpenResty config (loads Lua script)
├── limit.lua            # Core Lua rate-limiting logic
├── conf.d/              # Extra Nginx configs
├── html/                # Static assets
└── redis-data/          # Redis persistence
``` 

## Deployment

### Prerequisites

- Docker ≥ 20.10
- Docker Compose v2
- Port 80 (or custom port) open on the host
- Optional: adequate disk if you persist Redis data

### Clone and Start

```bash
# Clone repository
git clone https://github.com/APITWO/APITWO.git
cd APITWO

# One-click start
docker compose up -d
```

This boots two containers:

| Container | Port | Purpose |
|-----------|------|---------|
| `redis`   | 6379 | Counter storage |
| `openresty` | 80 | API entry & rate limiting |

### Customization

| Need | File / Location | How to change |
|------|-----------------|---------------|
| Change thresholds | `limit.lua` | Edit the `limits` table |
| Swap backend target | `nginx.conf` | Update `proxy_pass` |
| Use JWT / API key | `limit.lua` | Rewrite `get_client_key()` |
| Enable HTTPS | `nginx.conf` | Mount certs & listen on 443 |
| Inject env vars | `docker-compose.yml` | Add `environment:` block |
| Logging & metrics | container logs | Pipe to ELK / Loki etc. |

#### Hot Reload

```bash
docker exec openresty nginx -s reload   # reload after editing Lua/Nginx files
```

### Production Tips

1. Use Redis replication/cloud service to avoid single point of failure.
2. Scale OpenResty horizontally; counters live in Redis so workers stay stateless.
3. Tune `red:set_timeout()` and connection pool settings in Lua.
4. Use IP-hash or consistent hashing on upstream load balancers if needed. 

## Demo

Below is a quick demonstration of the minute-level limit (default: 5 requests/minute). After five successful requests, the sixth and subsequent ones within the same minute receive `429 Too Many Requests`. A Redis query shows the three keys (day/hour/minute) generated for the client IP.

```bash
~$ curl http://localhost
{
  "origin": "192.168.65.1"
}
~$ curl http://localhost
{
  "origin": "192.168.65.1"
}
~$ curl http://localhost
{
  "origin": "192.168.65.1"
}
~$ curl http://localhost
{
  "origin": "192.168.65.1"
}
~$ curl http://localhost
{
  "origin": "192.168.65.1"
}
~$ curl http://localhost
{"msg":"Request too frequent (minute)","code":429}
~$ curl http://localhost
{"msg":"Request too frequent (minute)","code":429}

$ docker exec -it redis redis-cli
127.0.0.1:6379> keys *
1) "limit:minute:192.168.65.1:202506291538"
2) "limit:hour:192.168.65.1:2025062915"
3) "limit:day:192.168.65.1:20250629"
```

## Typical Use Cases

| Scenario            | Benefit / Effect                          | Notes |
|---------------------|-------------------------------------------|-------|
| Public API Gateway  | Prevent abuse of free endpoints           | Minute/hour limits shield backend |
| SaaS Multi-Tenant   | Rate-limit per tenant or user ID          | Combine with JWT to fetch `tenant_id` |
| Microservices Mesh  | Stop cascading failures between services  | Put in front of internal APIs |
| Login / Register    | Block brute-force attacks                 | Limit by IP or account identifier |
| E-commerce Flash Sale | Balance human vs. bot traffic            | Pair with CAPTCHA, sliding verify |
| IoT Device Upload   | Keep firmware / heartbeat under control   | Limit each device's frequency |
| Freemium Quota      | Tier-based billing                        | Low limits for free tier, dynamic for paid |
| Webhook Callbacks   | Protect inbound callbacks                 | Avoid accidental DDOS from partners |

## Comparison with Other Solutions

| Solution              | Performance | Flexibility | Complexity |
|-----------------------|-------------|-------------|------------|
| Nginx `limit_req`     | High        | Low (fixed rate) | Low |
| Kong / APISIX         | High        | High (plugin system) | Medium |
| **This project**      | High        | High (Lua scripting) | Low-Medium |

## FAQ

1. **Is the counter accurate?**  
   Redis `INCR` + `EXPIRE` is atomic—yes, the counts are reliable.
2. **Need distributed locks?**  
   No. The `INCR` operation is atomic, no extra locks required.
3. **How to expose remaining quota?**  
   Add `limit - count` to response headers, or offer a dedicated query endpoint.
4. **Does it support sliding window?**  
   Current algorithm is fixed-window; you can refactor the Lua script for sliding window or token bucket.

## Contributing

Pull requests and issues are welcome! Please follow best practices for Lua, Nginx, and Docker.

## License

This project is licensed under the MIT License. 