# vsm_rate_limiter

Elixir rate limiter with pluggable backends (token bucket, ExRated, Hammer) and VSM subsystem-aware rate policies. Includes algedonic alerting when usage crosses configurable thresholds.

## Status

- Version: 0.1.0
- OTP app with supervision tree
- 1 test file; coverage unknown
- Published to Hex (no organization scoping)

## What it does

Routes rate-limit checks through a configurable adapter. Each VSM subsystem (S1 through S5) can have its own rate limit and threshold. When usage ratio crosses the algedonic threshold, an alert is triggered.

## Modules

| Module | Purpose |
|--------|---------|
| `VsmRateLimiter` | Public API: configure_subsystem, check_rate, get_status, reset, use_adapter |
| `VsmRateLimiter.Core` | Delegates to the active adapter based on application config |
| `VsmRateLimiter.TokenBucket` | Built-in token bucket implementation |
| `VsmRateLimiter.Adapters.ExRated` | Adapter for the ex_rated library |
| `VsmRateLimiter.Adapters.Hammer` | Adapter for the Hammer library |
| `VsmRateLimiter.Algedonic` | Fires alerts when usage exceeds threshold |
| `VsmRateLimiter.SubsystemManager` | Stores per-subsystem configuration |
| `VsmRateLimiter.Adapter` | Behaviour definition for adapters |

## Supported VSM subsystems

| Key | Subsystem | Typical use |
|-----|-----------|-------------|
| `:s1_environment` | Operations | High-volume environment monitoring |
| `:s2_coordination` | Coordination | Inter-unit coordination messages |
| `:s3_control` | Control | Operational control decisions |
| `:s3_star_audit` | Audit | Compliance and audit checks |
| `:s4_intelligence` | Intelligence | Intelligence gathering |
| `:s4_star_research` | Research | R&D queries |
| `:s5_policy` | Policy | Low volume, high priority |

## Installation

```elixir
def deps do
  [{:vsm_rate_limiter, "~> 0.1.0"}]
end
```

## Usage

```elixir
# Configure a subsystem
VsmRateLimiter.configure_subsystem(:s1_environment,
  rate_limit: {100, :requests_per_minute},
  algedonic_threshold: 0.8
)

# Check rate
case VsmRateLimiter.check_rate(:s1_environment, "user_123") do
  {:ok, remaining} -> proceed(remaining)
  {:error, :rate_limited} -> reject()
end

# Switch adapter at runtime
VsmRateLimiter.use_adapter(:hammer)
```

## Configuration

```elixir
config :vsm_rate_limiter,
  adapter: :token_bucket,
  default_rate_limit: {100, :requests_per_minute},
  algedonic_threshold: 0.8
```

## Limitations

- Adapter switching at runtime uses `Application.put_env`, which is a global side effect
- SubsystemManager state storage mechanism is not visible from the public API; likely ETS or Agent
- Only 1 test file for the entire library
- No benchmarks comparing adapter performance
- No distributed rate limiting; each node operates independently

## License

MIT
