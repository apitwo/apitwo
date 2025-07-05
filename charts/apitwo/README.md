# APITWO Helm Chart

A high-performance API rate-limiting gateway built with OpenResty, Lua, and Redis.

## Introduction

This chart deploys APITWO on a Kubernetes cluster using the Helm package manager.

## Prerequisites

- Kubernetes 1.21+
- Helm 3.0+
- PV provisioner support in the underlying infrastructure

## Installing the Chart

```bash
# Add the repository
helm repo add apitwo https://apitwo.github.io/helm-charts

# Install the chart
helm install my-apitwo apitwo/apitwo
```

## Configuration

The following table lists the configurable parameters of the apitwo chart and their default values.

| Parameter | Description | Default |
|-----------|-------------|---------|
| `redis.image` | Redis image | `"redis:alpine"` |
| `redis.port` | Redis port | `6379` |
| `redis.host` | Redis host | `"redis"` |
| `redis.persistence.enabled` | Enable Redis persistence | `true` |
| `redis.persistence.size` | Redis PVC size | `10Gi` |
| `redis.persistence.storageClass` | Redis storage class | `""` |
| `openresty.image` | OpenResty image | `"openresty/openresty:alpine"` |
| `openresty.port` | OpenResty port | `80` |
| `openresty.replicaCount` | OpenResty replicas | `1` |
| `openresty.service.type` | OpenResty service type | `ClusterIP` |
| `openresty.dnsResolver` | DNS resolver | `""` |

### Rate Limiting Configuration

The rate limiting thresholds can be configured by modifying the `limit.lua` file in the ConfigMap:

```lua
local limits = {
    day = 500,    -- Max requests per day
    hour = 50,    -- Max requests per hour
    minute = 5    -- Max requests per minute
}
```

## Usage

After installation, the API gateway will be available at the OpenResty service endpoint.

### Testing Rate Limiting

```bash
# Test the API (first 5 requests should succeed)
curl http://your-openresty-service

# After 5 requests in a minute, you'll get:
# {"msg":"Request too frequent (minute)","code":429}
```

### Monitoring

Check the logs:

```bash
# OpenResty logs
kubectl logs -l app.kubernetes.io/name=apitwo,app.kubernetes.io/component=openresty

# Redis logs
kubectl logs -l app.kubernetes.io/name=apitwo,app.kubernetes.io/component=redis
```

## Uninstalling the Chart

```bash
helm uninstall my-apitwo
```

## Contributing

Please read [CONTRIBUTING.md](https://github.com/APITWO/APITWO/blob/main/CONTRIBUTING.md) for details on our code of conduct and the process for submitting pull requests.

## License

This project is licensed under the MIT License - see the [LICENSE](https://github.com/APITWO/APITWO/blob/main/LICENSE) file for details.