local redis = require "resty.redis" -- 引入 redis 库 Import redis lib
local cjson = require "cjson" -- 引入 cjson 库 Import cjson lib

-- 配置 Configuration
local limits = {
    day = 500,    -- 每天最大请求数 Max requests per day
    hour = 50,    -- 每小时最大请求数 Max requests per hour
    minute = 5    -- 每分钟最大请求数 Max requests per minute
}

-- 使用 nginx 变量获取 Redis 连接信息
local redis_host = ngx.var.redis_host or "redis"   -- Redis host
local redis_port = tonumber(ngx.var.redis_port) or 6379  -- Redis port

-- 调试信息：输出 nginx 变量
ngx.log(ngx.ERR, "=== Redis Debug Info ===")
ngx.log(ngx.ERR, "ngx.var.redis_host: " .. (ngx.var.redis_host or "nil"))
ngx.log(ngx.ERR, "ngx.var.redis_port: " .. (ngx.var.redis_port or "nil"))
ngx.log(ngx.ERR, "Final redis_host: " .. redis_host)
ngx.log(ngx.ERR, "Final redis_port: " .. redis_port)

-- 获取客户端唯一标识（可根据实际需求调整） Get client unique key (adjust as needed)
-- ngx.var.remote_addr
-- ngx.var.http_x_forwarded_for
local function get_client_key()
    return ngx.var.remote_addr or "unknown" -- 使用远程地址 Use remote address
end

local function get_time_keys()
    local now = os.time() -- 当前时间戳 Current timestamp
    local day = os.date("%Y%m%d", now)   -- 天 key Day key
    local hour = os.date("%Y%m%d%H", now) -- 小时 key Hour key
    local minute = os.date("%Y%m%d%H%M", now) -- 分钟 key Minute key
    return day, hour, minute
end

local function rate_limit()
    local client = get_client_key() -- 客户端标识 Client key
    local day, hour, minute = get_time_keys() -- 时间 keys Time keys
    local keys = {
        day = "limit:day:" .. client .. ":" .. day, -- 天限流 key Day limit key
        hour = "limit:hour:" .. client .. ":" .. hour, -- 小时限流 key Hour limit key
        minute = "limit:minute:" .. client .. ":" .. minute -- 分钟限流 key Minute limit key
    }
    local ttl = { day = 86400, hour = 3600, minute = 60 } -- 过期时间 Expire time

    local red = redis:new() -- 创建 redis 实例 Create redis instance
    red:set_timeout(1000) -- 设置超时时间 Set timeout
    local ok, err = red:connect(redis_host, redis_port) -- 连接 Redis Connect Redis
    if not ok then
        ngx.status = 500
        ngx.say(cjson.encode({ code = 500, msg = "Redis connection failed: " .. (err or "") })) -- Redis connection failed
        return ngx.exit(500)
    end

    for k, key in pairs(keys) do
        local limit = limits[k] -- 限流阈值 Limit threshold
        local expire = ttl[k]   -- 过期时间 Expire time
        local count, err = red:incr(key) -- 计数器自增 Counter increment
        if not count then
            ngx.status = 500
            ngx.say(cjson.encode({ code = 500, msg = "Redis count failed: " .. (err or "") })) -- Redis count failed
            return ngx.exit(500)
        end
        if count == 1 then
            red:expire(key, expire) -- 首次设置过期 Set expire on first set
        end
        if count > limit then
            ngx.status = 429
            ngx.say(cjson.encode({ code = 429, msg = "Request too frequent (" .. k .. ")" }))
            return ngx.exit(429)
        end
    end
end

rate_limit() -- 执行限流逻辑 Run rate limit logic 