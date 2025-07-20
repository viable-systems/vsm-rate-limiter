defmodule VsmRateLimiter.Application do
  @moduledoc """
  OTP Application for VSM Rate Limiter.
  
  Manages the supervision tree for rate limiting components including:
  - Token bucket processes
  - Adapter supervisors
  - Algedonic alert system
  - Telemetry collectors
  """
  
  use Application
  require Logger

  @impl true
  def start(_type, _args) do
    children = [
      # Telemetry supervisor
      {Telemetry.Metrics.ConsoleReporter, metrics: metrics()},
      
      # Token bucket registry
      {Registry, keys: :unique, name: VsmRateLimiter.BucketRegistry},
      
      # Dynamic supervisor for token buckets
      {DynamicSupervisor, name: VsmRateLimiter.BucketSupervisor, strategy: :one_for_one},
      
      # Algedonic system for critical alerts
      VsmRateLimiter.Algedonic,
      
      # Subsystem manager
      VsmRateLimiter.SubsystemManager,
      
      # Adapter managers
      VsmRateLimiter.Adapters.ExRated.Supervisor,
      VsmRateLimiter.Adapters.Hammer.Supervisor
    ]

    opts = [strategy: :one_for_one, name: VsmRateLimiter.Supervisor]
    
    Logger.info("Starting VSM Rate Limiter Application")
    Supervisor.start_link(children, opts)
  end

  defp metrics do
    [
      # Rate limiter metrics
      Telemetry.Metrics.counter("vsm_rate_limiter.request.allowed"),
      Telemetry.Metrics.counter("vsm_rate_limiter.request.rejected"),
      Telemetry.Metrics.summary("vsm_rate_limiter.request.duration"),
      
      # Token bucket metrics
      Telemetry.Metrics.last_value("vsm_rate_limiter.bucket.tokens"),
      Telemetry.Metrics.counter("vsm_rate_limiter.bucket.refill"),
      
      # Algedonic metrics
      Telemetry.Metrics.counter("vsm_rate_limiter.algedonic.alert"),
      Telemetry.Metrics.summary("vsm_rate_limiter.algedonic.severity"),
      
      # Subsystem metrics
      Telemetry.Metrics.counter("vsm_rate_limiter.subsystem.limit_exceeded"),
      Telemetry.Metrics.distribution("vsm_rate_limiter.subsystem.variety_level")
    ]
  end
end