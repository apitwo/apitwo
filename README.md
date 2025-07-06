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
- **Kubernetes Helm Chart support**: Complete K8s deployment solution
- **Dynamic service discovery**: Auto-detect Redis service IP

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
├── docker/                    # Docker deployment files
│   ├── docker-compose.yml     # Redis + OpenResty services
│   ├── nginx.conf             # Main OpenResty config (loads Lua script)
│   ├── limit.lua              # Core Lua rate-limiting logic
│   ├── conf.d/                # Extra Nginx configs
│   ├── html/                  # Static assets
│   └── redis-data/            # Redis persistence
├── charts/                    # Kubernetes Helm Chart
│   └── apitwo/
│       ├── Chart.yaml         # Chart metadata
│       ├── values.yaml        # Default configuration values
│       ├── templates/         # K8s resource templates
│       └── files/             # Configuration file templates
├── README.md                  # English documentation
├── README_ZH.md               # Chinese documentation
└── LICENSE                    # Open source license
```

## Deployment

### Option 1: Docker Compose Deployment

#### Prerequisites

- Docker ≥ 20.10
- Docker Compose v2
- Port 80 (or custom port) open on the host
- Optional: adequate disk if you persist Redis data

#### Clone and Start

```bash
# Clone repository
git clone https://github.com/APITWO/APITWO.git
cd APITWO

# Enter docker directory
cd docker

# One-click start
docker compose up -d
```

This boots two containers:

| Container | Port | Purpose |
|-----------|------|---------|
| `redis`   | 6379 | Counter storage |
| `openresty` | 80 | API entry & rate limiting |

#### Customization

| Need | File / Location | How to change |
|------|-----------------|---------------|
| Change thresholds | `docker/limit.lua` | Edit the `limits` table |
| Swap backend target | `docker/nginx.conf` | Update `proxy_pass` |
| Use JWT / API key | `docker/limit.lua` | Rewrite `get_client_key()` |
| Enable HTTPS | `docker/nginx.conf` | Mount certs & listen on 443 |
| Inject env vars | `docker/docker-compose.yml` | Add `environment:` block |
| Logging & metrics | container logs | Pipe to ELK / Loki etc. |

#### Hot Reload

```bash
docker exec openresty nginx -s reload   # reload after editing Lua/Nginx files
```

### Option 2: Kubernetes Helm Deployment

#### Prerequisites

- A reachable Kubernetes cluster (v1.21+ recommended)
- [Helm 3](https://helm.sh/) installed locally (`brew install helm` or official install script)

#### Quick start

```bash
# (Optional) Create a dedicated namespace
kubectl create ns apitwo

# Install from the local chart directory
helm install apitwo ./charts/apitwo -n apitwo
```

Helm will create:

| Resource | Purpose |
|----------|---------|
| `StatefulSet/redis` + `Service/redis` | Counter storage |
| `Deployment/openresty` + `Service/openresty` | API entry & rate limiting |
| `ConfigMap/openresty-conf` | Ships `nginx.conf` / `limit.lua` to the Pod |

#### Customising values

Most knobs live in `charts/apitwo/values.yaml`. Override on the command line, e.g.:

```bash
# Expose OpenResty with a LoadBalancer Service and disable Redis persistence
helm upgrade apitwo ./charts/apitwo -n apitwo \
  --set openresty.service.type=LoadBalancer \
  --set redis.persistence.enabled=false
```

#### Verify & lint

```bash
helm lint ./charts/apitwo            # YAML & template checks
helm template apitwo ./charts/apitwo # Render manifests without installing
```

#### Uninstall

```bash
helm uninstall apitwo -n apitwo
```

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

## Technical Implementation Details

### Redis Connection Optimization

- **Docker Environment**: Use service name `redis` for DNS resolution
- **Kubernetes Environment**: Dynamically obtain Redis service ClusterIP, avoiding hardcoding
- **Connection Pool Management**: Use `lua_shared_dict` to manage Redis connections
- **Error Handling**: Comprehensive connection failure and timeout handling mechanisms

### Rate Limiting Algorithm

- **Fixed Window**: Count requests by day/hour/minute
- **Atomic Operations**: Use Redis `INCR` + `EXPIRE` to ensure counting accuracy
- **Auto Expiration**: Avoid memory leaks, automatically clean up expired counters

### Configuration Hot Reload

- **ConfigMap Change Detection**: Helm Chart automatically detects configuration changes
- **Pod Rolling Updates**: Automatically restart related Pods when configuration changes
- **Zero-Downtime Deployment**: Support blue-green deployment and rolling updates

## FAQ

1. **Is the counter accurate?**  
   Redis `INCR` + `EXPIRE` is atomic—yes, the counts are reliable.

2. **Need distributed locks?**  
   No. The `INCR` operation is atomic, no extra locks required.

3. **How to expose remaining quota?**  
   Add `limit - count` to response headers, or offer a dedicated query endpoint.

4. **Does it support sliding window?**  
   Current algorithm is fixed-window; you can refactor the Lua script for sliding window or token bucket.

5. **What if Redis connection fails?**  
   - Docker environment: Check container networking and DNS resolution
   - K8s environment: Check service discovery and network policies
   - Check OpenResty logs for detailed error messages

6. **How to monitor rate limiting effectiveness?**  
   - Check OpenResty access logs
   - Monitor counter keys in Redis
   - Integrate with Prometheus + Grafana for visualization

## Contributing

Pull requests and issues are welcome! Please follow best practices for Lua, Nginx, Docker, and Kubernetes.

## License

This project is licensed under the MIT License. 