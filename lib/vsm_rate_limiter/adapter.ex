defmodule VsmRateLimiter.Adapter do
  @moduledoc """
  Behaviour for rate limiter adapters.
  """
  
  @doc """
  Check if a request is allowed under the rate limit.
  
  Returns {:ok, remaining_requests} if allowed, {:error, :rate_limited} if not.
  """
  @callback check_rate(key :: String.t(), config :: keyword()) :: 
    {:ok, remaining :: non_neg_integer()} | {:error, :rate_limited}
  
  @doc """
  Get the current status of a rate limit key.
  """
  @callback get_status(key :: String.t()) :: map()
  
  @doc """
  Reset the rate limit for a key.
  """
  @callback reset(key :: String.t()) :: :ok
end