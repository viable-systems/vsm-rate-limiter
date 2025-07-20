import Config

# Configure Hammer backend
config :hammer,
  backend: {Hammer.Backend.ETS, [
    expiry_ms: :timer.hours(1),
    cleanup_interval_ms: :timer.minutes(5),
    size: :infinity
  ]}

# Configure VSM Rate Limiter
config :vsm_rate_limiter,
  adapter: :token_bucket,
  default_rate_limit: {100, :requests_per_minute},
  algedonic_threshold: 0.8