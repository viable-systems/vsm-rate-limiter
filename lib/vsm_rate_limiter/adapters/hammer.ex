defmodule VsmRateLimiter.Adapters.Hammer do
  @moduledoc """
  Adapter for the Hammer rate limiting library.
  """
  
  @behaviour VsmRateLimiter.Adapter
  
  @doc """
  Check rate limit using Hammer.
  """
  def check_rate(key, config) do
    {limit, unit} = Keyword.get(config, :rate_limit, {100, :requests_per_minute})
    scale_ms = time_unit_to_ms(unit)
    
    case Hammer.check_rate(key, scale_ms, limit) do
      {:allow, count} ->
        remaining = limit - count
        
        :telemetry.execute(
          [:vsm_rate_limiter, :request, :allowed],
          %{remaining: remaining, adapter: :hammer},
          %{key: key}
        )
        
        {:ok, remaining}
        
      {:deny, _limit} ->
        :telemetry.execute(
          [:vsm_rate_limiter, :request, :rejected],
          %{adapter: :hammer},
          %{key: key}
        )
        
        {:error, :rate_limited}
    end
  end
  
  @doc """
  Get current status from Hammer.
  """
  def get_status(key) do
    case Hammer.inspect_bucket(key) do
      {bucket_info, count, created_at, updated_at} ->
        %{
          exists: true,
          current_count: count,
          created_at: created_at,
          updated_at: updated_at,
          bucket_info: bucket_info,
          adapter: :hammer
        }
      nil ->
        %{exists: false, adapter: :hammer}
    end
  end
  
  @doc """
  Reset rate limit by deleting the bucket.
  """
  def reset(key) do
    Hammer.delete_buckets(key)
    :ok
  end
  
  defp time_unit_to_ms(:requests_per_second), do: 1_000
  defp time_unit_to_ms(:requests_per_minute), do: 60_000
  defp time_unit_to_ms(:requests_per_hour), do: 3_600_000
end

defmodule VsmRateLimiter.Adapters.Hammer.Supervisor do
  @moduledoc false
  
  use Supervisor
  
  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  @impl true
  def init(_opts) do
    children = [
      # Hammer backend configuration
      {Hammer.Backend.ETS, [
        expiry_ms: :timer.hours(1),
        cleanup_interval_ms: :timer.minutes(5)
      ]}
    ]
    
    Supervisor.init(children, strategy: :one_for_one)
  end
end