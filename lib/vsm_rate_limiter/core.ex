defmodule VsmRateLimiter.Core do
  @moduledoc """
  Core rate limiting logic that delegates to configured adapters.
  """
  
  alias VsmRateLimiter.TokenBucket
  
  @doc """
  Check rate limit using the configured adapter.
  """
  def check_rate(subsystem, identifier, config) do
    adapter = get_adapter()
    key = build_key(subsystem, identifier)
    
    case adapter do
      :token_bucket ->
        TokenBucket.check_rate(key, config)
      :ex_rated ->
        VsmRateLimiter.Adapters.ExRated.check_rate(key, config)
      :hammer ->
        VsmRateLimiter.Adapters.Hammer.check_rate(key, config)
    end
  end
  
  @doc """
  Get current status for a rate limit key.
  """
  def get_status(subsystem, identifier) do
    adapter = get_adapter()
    key = build_key(subsystem, identifier)
    
    case adapter do
      :token_bucket ->
        TokenBucket.get_status(key)
      :ex_rated ->
        VsmRateLimiter.Adapters.ExRated.get_status(key)
      :hammer ->
        VsmRateLimiter.Adapters.Hammer.get_status(key)
    end
  end
  
  @doc """
  Reset rate limit for a key.
  """
  def reset(subsystem, identifier) do
    adapter = get_adapter()
    key = build_key(subsystem, identifier)
    
    case adapter do
      :token_bucket ->
        TokenBucket.reset(key)
      :ex_rated ->
        VsmRateLimiter.Adapters.ExRated.reset(key)
      :hammer ->
        VsmRateLimiter.Adapters.Hammer.reset(key)
    end
  end
  
  defp get_adapter do
    Application.get_env(:vsm_rate_limiter, :adapter, :token_bucket)
  end
  
  defp build_key(subsystem, identifier) do
    "#{subsystem}:#{identifier}"
  end
end