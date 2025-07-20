defmodule VsmRateLimiter.Adapters.ExRated do
  @moduledoc """
  Adapter for the ExRated rate limiting library.
  """
  
  @behaviour VsmRateLimiter.Adapter
  
  @doc """
  Check rate limit using ExRated.
  """
  def check_rate(key, config) do
    {limit, unit} = Keyword.get(config, :rate_limit, {100, :requests_per_minute})
    scale_ms = time_unit_to_ms(unit)
    
    case ExRated.check_rate(key, scale_ms, limit) do
      {:ok, count} ->
        remaining = limit - count
        
        :telemetry.execute(
          [:vsm_rate_limiter, :request, :allowed],
          %{remaining: remaining, adapter: :ex_rated},
          %{key: key}
        )
        
        {:ok, remaining}
        
      {:error, _limit} ->
        :telemetry.execute(
          [:vsm_rate_limiter, :request, :rejected],
          %{adapter: :ex_rated},
          %{key: key}
        )
        
        {:error, :rate_limited}
    end
  end
  
  @doc """
  Get current status from ExRated.
  """
  def get_status(key) do
    # ExRated requires scale_ms and limit parameters for inspect_bucket
    case ExRated.inspect_bucket(key, 60_000, 100) do
      {_, count, _, _, _} = bucket ->
        %{
          exists: true,
          current_count: count,
          bucket_info: bucket,
          adapter: :ex_rated
        }
      _ ->
        %{exists: false, adapter: :ex_rated}
    end
  end
  
  @doc """
  Reset rate limit by deleting the bucket.
  """
  def reset(key) do
    ExRated.delete_bucket(key)
    :ok
  end
  
  defp time_unit_to_ms(:requests_per_second), do: 1_000
  defp time_unit_to_ms(:requests_per_minute), do: 60_000
  defp time_unit_to_ms(:requests_per_hour), do: 3_600_000
end

defmodule VsmRateLimiter.Adapters.ExRated.Supervisor do
  @moduledoc false
  
  use Supervisor
  
  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  @impl true
  def init(_opts) do
    children = [
      # ExRated is started as part of its application
    ]
    
    Supervisor.init(children, strategy: :one_for_one)
  end
end