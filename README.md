# VSM Rate Limiter

A sophisticated rate limiting library for Elixir that implements Viable System Model (VSM) principles with variety attenuation, pluggable adapters, and algedonic signaling.

## Features

- **VSM-based Architecture**: Rate limiting organized by VSM subsystems (S1-S5)
- **Variety Attenuation**: Implements Ashby's Law of Requisite Variety
- **Multiple Adapters**: Support for token bucket, ExRated, and Hammer
- **Algedonic System**: Critical alerts and pain/pleasure signals
- **Subsystem-specific Limits**: Different rate limits for each VSM subsystem
- **Telemetry Integration**: Built-in metrics and monitoring

## Installation

Add `vsm_rate_limiter` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:vsm_rate_limiter, "~> 0.1.0"}
  ]
end
```

## Usage

### Basic Rate Limiting

```elixir
# Configure a subsystem
VsmRateLimiter.configure_subsystem(:s1_environment, 
  rate_limit: {100, :requests_per_minute},
  algedonic_threshold: 0.8
)

# Check rate limit
case VsmRateLimiter.check_rate(:s1_environment, "user_123") do
  {:ok, remaining} -> 
    IO.puts("Request allowed. #{remaining} requests remaining")
  {:error, :rate_limited} ->
    IO.puts("Rate limit exceeded")
end
```

### Using Different Adapters

```elixir
# Use ExRated adapter
VsmRateLimiter.use_adapter(:ex_rated)

# Use Hammer adapter
VsmRateLimiter.use_adapter(:hammer)

# Default is token bucket
VsmRateLimiter.use_adapter(:token_bucket)
```

### VSM Subsystems

The library supports all VSM subsystems:

- `:s1_environment` - Environment monitoring (highest volume)
- `:s2_coordination` - Coordination between units
- `:s3_control` - Operational control
- `:s3_star_audit` - Audit and compliance
- `:s4_intelligence` - Intelligence gathering
- `:s4_star_research` - Research and development
- `:s5_policy` - Policy decisions (lowest volume, highest priority)

### Algedonic Alerts

Register handlers for critical system events:

```elixir
VsmRateLimiter.Algedonic.register_handler(fn alert, severity, metadata ->
  case severity do
    :critical -> 
      # Send emergency notification
      notify_ops_team(alert)
    :high ->
      # Log to monitoring system
      Logger.warning("High severity alert", alert: alert)
    _ ->
      :ok
  end
end)
```

### Monitoring

The library emits telemetry events for monitoring:

```elixir
# Attach to telemetry events
:telemetry.attach(
  "rate-limiter-handler",
  [:vsm_rate_limiter, :request, :allowed],
  &handle_event/4,
  nil
)

def handle_event([:vsm_rate_limiter, :request, :allowed], measurements, metadata, _config) do
  IO.puts("Request allowed with #{measurements.remaining} remaining")
end
```

## Architecture

The VSM Rate Limiter implements key cybernetic principles:

1. **Variety Attenuation**: Reduces the variety of incoming requests to match system capacity
2. **Hierarchical Control**: Different rate limits based on VSM subsystem hierarchy
3. **Algedonic Signaling**: Pain/pleasure signals for critical events
4. **Adaptive Behavior**: Dynamic rate limiting based on system load

## Configuration

Configure in your application:

```elixir
config :vsm_rate_limiter,
  adapter: :token_bucket,
  default_rate_limit: {100, :requests_per_minute},
  algedonic_threshold: 0.8
```

## Testing

```bash
mix test
```

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b feature/my-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin feature/my-feature`)
5. Create new Pull Request

## License

MIT License - see LICENSE file for details