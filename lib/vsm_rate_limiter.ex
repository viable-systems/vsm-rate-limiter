defmodule VsmRateLimiter do
  @moduledoc """
  VSM Rate Limiter provides variety attenuation for Viable System Model implementations.
  
  This library offers:
  - Pluggable adapters for popular rate limiting libraries (ex_rated, hammer)
  - Token bucket algorithm implementation
  - Algedonic integration for critical system alerts
  - Subsystem-specific rate limiting based on VSM architecture
  - Telemetry integration for monitoring and alerting
  
  ## Usage
  
      # Configure subsystem rate limits
      VsmRateLimiter.configure_subsystem(:s1_environment, 
        rate_limit: {100, :requests_per_minute},
        algedonic_threshold: 0.8
      )
      
      # Check rate limit
      case VsmRateLimiter.check_rate(:s1_environment, "user_123") do
        {:ok, remaining} -> 
          # Request allowed
        {:error, :rate_limited} ->
          # Request rejected
      end
  """
  
  alias VsmRateLimiter.{Core, Algedonic, SubsystemManager}
  
  @type subsystem :: atom()
  @type identifier_t :: String.t()
  @type rate_limit :: {pos_integer(), time_unit()}
  @type time_unit :: :requests_per_second | :requests_per_minute | :requests_per_hour
  
  @doc """
  Configure rate limiting for a VSM subsystem.
  """
  @spec configure_subsystem(subsystem(), keyword()) :: :ok | {:error, term()}
  def configure_subsystem(subsystem, opts) do
    SubsystemManager.configure(subsystem, opts)
  end
  
  @doc """
  Check if a request is allowed for the given subsystem and identifier.
  """
  @spec check_rate(subsystem(), identifier_t()) :: {:ok, pos_integer()} | {:error, :rate_limited}
  def check_rate(subsystem, identifier) do
    with {:ok, config} <- SubsystemManager.get_config(subsystem),
         {:ok, remaining} <- Core.check_rate(subsystem, identifier, config) do
      # Check algedonic threshold
      check_algedonic_threshold(subsystem, {:ok, remaining}, config)
      {:ok, remaining}
    end
  end
  
  @doc """
  Get current rate limit status for a subsystem.
  """
  @spec get_status(subsystem(), identifier_t()) :: map()
  def get_status(subsystem, identifier) do
    Core.get_status(subsystem, identifier)
  end
  
  @doc """
  Reset rate limit for a specific identifier in a subsystem.
  """
  @spec reset(subsystem(), identifier_t()) :: :ok
  def reset(subsystem, identifier) do
    Core.reset(subsystem, identifier)
  end
  
  @doc """
  Configure the adapter to use (ex_rated or hammer).
  """
  @spec use_adapter(:ex_rated | :hammer) :: :ok
  def use_adapter(adapter) when adapter in [:ex_rated, :hammer, :token_bucket] do
    Application.put_env(:vsm_rate_limiter, :adapter, adapter)
  end
  
  # Private functions
  
  defp check_algedonic_threshold(subsystem, {:ok, remaining} = result, config) do
    threshold = Keyword.get(config, :algedonic_threshold, 0.8)
    limit = get_limit_from_config(config)
    
    usage_ratio = 1 - (remaining / limit)
    
    if usage_ratio >= threshold do
      Algedonic.trigger_alert(subsystem, :high_usage, %{
        usage_ratio: usage_ratio,
        remaining: remaining,
        limit: limit
      })
    end
    
    result
  end
  
  defp check_algedonic_threshold(_subsystem, error, _config), do: error
  
  defp get_limit_from_config(config) do
    case Keyword.get(config, :rate_limit) do
      {limit, _unit} -> limit
      _ -> 100  # Default
    end
  end
end
