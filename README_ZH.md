# APITWO

[English README](README.md)

## 项目简介

**APITWO** 是一个基于 **OpenResty**、**Lua** 与 **Redis** 的轻量级高性能 API 限流网关，支持分钟 / 小时 / 天多级限流，适用于微服务、公共 API、Webhook 等多种需要流量控制的场景。

## 主要特性

- 多级限流：按天 / 小时 / 分钟
- 阈值可配置：修改 `limit.lua` 即可
- 支持按 JWT / 用户 ID 维度限流（重写 `get_client_key()`）
- Lua & Nginx 配置热加载
- Docker Compose 一键部署

## 架构示意图

```
+----------+     +--------------+     +----------+
|  Client  | --> |  OpenResty   | --> |  Backend |
+----------+     | (limit.lua)  |     +----------+
                 |   Redis      |
                 +--------------+
```

## 目录结构

```
├── docker-compose.yml   # Redis + OpenResty 服务编排
├── nginx.conf           # OpenResty 主配置（加载 Lua 脚本）
├── limit.lua            # 核心 Lua 限流逻辑
├── conf.d/              # 其他 Nginx 配置
├── html/                # 静态资源
└── redis-data/          # Redis 数据持久化
```

## 部署指南

### 前置条件

- Docker ≥ 20.10
- Docker Compose v2
- 服务器开放 80 端口（或自定义端口）
- 如需持久化 Redis，请确保磁盘空间充足

### 克隆 & 启动

```bash
# 克隆仓库
git clone https://github.com/APITWO/APITWO.git
cd APITWO

# 一键启动
docker compose up -d
```

启动后会生成两个容器：

| 容器 | 端口 | 作用 |
|------|------|------|
| `redis` | 6379 | 计数存储 |
| `openresty` | 80 | API 网关 + 限流 |

### 自定义配置

| 需求 | 文件 / 位置 | 修改方法 |
|------|-------------|---------|
| 调整限流阈值 | `limit.lua` | 编辑 `limits` 表 |
| 更换后端服务 | `nginx.conf` | 修改 `proxy_pass` |
| 使用 JWT / API Key | `limit.lua` | 重写 `get_client_key()` |
| 启用 HTTPS | `nginx.conf` | 挂载证书，监听 443 |
| 注入环境变量 | `docker-compose.yml` | 添加 `environment:` |
| 日志 & 监控 | 容器日志 | 对接 ELK / Loki 等 |

#### 热更新

```bash
docker exec openresty nginx -s reload   # 修改 Lua/Nginx 后热加载
```

### 生产环境建议

1. Redis 建议主从或使用云托管版，避免单点故障。
2. OpenResty 容器可水平扩容，因计数存于 Redis，实例无状态。
3. 根据业务调优 `red:set_timeout()` 与连接池参数。
4. 上层负载均衡可采用 IP Hash / 一致性哈希，保持会话一致。

## Demo

以下示例演示分钟级（默认 5 次/分钟）限流效果，前 5 次返回正常，第 6 次起返回 `429`。随后展示 Redis 中生成的 day / hour / minute 三种 key：

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

$ docker exec -it redis redis-cli
127.0.0.1:6379> keys *
1) "limit:minute:192.168.65.1:202506291538"
2) "limit:hour:192.168.65.1:2025062915"
3) "limit:day:192.168.65.1:20250629"
```

## 典型应用场景

| 场景 | 价值 / 效果 | 说明 |
|------|-------------|------|
| 公共 API 网关 | 防止免费接口被刷爆 | 分钟/小时限流保护后端 |
| SaaS 多租户 | 按租户 / 用户 ID 限流 | 结合 JWT 提取 `tenant_id` |
| 微服务间调用 | 阻断级联故障 | 内部 API 前增加防护 |
| 登录 / 注册 | 抗暴力破解 | 按 IP 或账号限速 |
| 电商秒杀 | 人机流量分流 | 配合验证码、滑块验证 |
| IoT 设备上报 | 控制固件 / 心跳频次 | 限制异常设备刷写 |
| 免费额度计划 | 分层计费 | 免费层低阈值，付费层可动态提升 |
| Webhook / 回调 | 防止第三方误 DDOS | 对回调接口限流 |

## 与其他方案对比

| 方案 | 性能 | 灵活度 | 复杂度 |
|------|------|--------|--------|
| Nginx `limit_req` | 高 | 低（固定速率） | 低 |
| Kong / APISIX | 高 | 高（插件体系） | 中 |
| **本项目** | 高 | 高（Lua 可编程） | 低 - 中 |

## 常见问题 FAQ

1. **计数是否精确？**  
   Redis `INCR` + `EXPIRE` 原子操作，计数可靠。
2. **需要分布式锁吗？**  
   不需要，`INCR` 已原子化。
3. **如何查看剩余额度？**  
   可在 Lua 中把 `limit - count` 写入响应头，或提供查询接口。
4. **支持滑动窗口吗？**  
   当前为固定窗口，可自行改为滑动窗口或令牌桶。

## 贡献

欢迎提交 Issue 和 PR！请遵循 Lua、Nginx、Docker 社区最佳实践。

## 使用 Helm 部署到 Kubernetes

仓库已内置完整的 Helm Chart（路径 `charts/apitwo`），无需推送到远程 Chart 仓库，可直接本地安装。

### 前置条件

- 可访问的 Kubernetes 集群（建议 v1.21+）
- 已安装 [Helm 3](https://helm.sh/)（macOS 可 `brew install helm`）

### 快速开始

```bash
# （可选）创建独立命名空间
kubectl create ns apitwo

# 从本地目录安装 Chart
helm install apitwo ./charts/apitwo -n apitwo
```

安装完成后会生成：

| 资源 | 作用 |
|------|------|
| `StatefulSet/redis` + `Service/redis` | 计数存储 |
| `Deployment/openresty` + `Service/openresty` | API 网关 & 限流 |
| `ConfigMap/openresty-conf` | 注入 `nginx.conf` / `limit.lua` |

### 覆盖默认值

所有可配置项集中在 `values.yaml`，例如：

```bash
# 把 OpenResty 暴露为 LoadBalancer 类型，并关闭 Redis 持久化
helm upgrade apitwo ./charts/apitwo -n apitwo \
  --set openresty.service.type=LoadBalancer \
  --set redis.persistence.enabled=false
```

### 验证与调试

```bash
helm lint ./charts/apitwo            # 模板语法检查
helm template apitwo ./charts/apitwo # 渲染成 YAML 查看
```

### 卸载

```bash
helm uninstall apitwo -n apitwo
```

## 许可证

本项目基于 MIT License 发布。 