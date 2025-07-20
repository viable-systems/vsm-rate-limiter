defmodule VsmRateLimiter.TokenBucket do
  @moduledoc """
  Token bucket algorithm implementation for rate limiting.
  
  Each bucket maintains a number of tokens that are consumed on each request
  and refilled at a constant rate.
  """
  
  use GenServer
  require Logger
  
  @registry VsmRateLimiter.BucketRegistry
  @supervisor VsmRateLimiter.BucketSupervisor
  
  defstruct [
    :key,
    :max_tokens,
    :tokens,
    :refill_rate,
    :refill_interval,
    :last_refill
  ]
  
  # Client API
  
  @doc """
  Check if a request is allowed by consuming a token.
  """
  def check_rate(key, config) do
    bucket = ensure_bucket_exists(key, config)
    
    GenServer.call(bucket, :consume_token)
  end
  
  @doc """
  Get current bucket status.
  """
  def get_status(key) do
    case Registry.lookup(@registry, key) do
      [{pid, _}] ->
        GenServer.call(pid, :get_status)
      [] ->
        %{exists: false}
    end
  end
  
  @doc """
  Reset bucket to full capacity.
  """
  def reset(key) do
    case Registry.lookup(@registry, key) do
      [{pid, _}] ->
        GenServer.call(pid, :reset)
      [] ->
        :ok
    end
  end
  
  # Server callbacks
  
  def start_link(args) do
    key = Keyword.fetch!(args, :key)
    GenServer.start_link(__MODULE__, args, name: via_tuple(key))
  end
  
  @impl true
  def init(args) do
    key = Keyword.fetch!(args, :key)
    config = Keyword.fetch!(args, :config)
    
    {limit, unit} = Keyword.get(config, :rate_limit, {100, :requests_per_minute})
    
    refill_interval = calculate_refill_interval(unit)
    refill_rate = calculate_refill_rate(limit, unit)
    
    state = %__MODULE__{
      key: key,
      max_tokens: limit,
      tokens: limit,
      refill_rate: refill_rate,
      refill_interval: refill_interval,
      last_refill: System.monotonic_time(:millisecond)
    }
    
    # Schedule periodic refill
    Process.send_after(self(), :refill, refill_interval)
    
    {:ok, state}
  end
  
  @impl true
  def handle_call(:consume_token, _from, state) do
    state = refill_tokens(state)
    
    if state.tokens >= 1 do
      new_state = %{state | tokens: state.tokens - 1}
      
      :telemetry.execute(
        [:vsm_rate_limiter, :request, :allowed],
        %{tokens_remaining: new_state.tokens},
        %{key: state.key}
      )
      
      {:reply, {:ok, trunc(new_state.tokens)}, new_state}
    else
      :telemetry.execute(
        [:vsm_rate_limiter, :request, :rejected],
        %{},
        %{key: state.key}
      )
      
      {:reply, {:error, :rate_limited}, state}
    end
  end
  
  @impl true
  def handle_call(:get_status, _from, state) do
    state = refill_tokens(state)
    
    status = %{
      exists: true,
      tokens: trunc(state.tokens),
      max_tokens: state.max_tokens,
      refill_rate: state.refill_rate,
      refill_interval: state.refill_interval
    }
    
    {:reply, status, state}
  end
  
  @impl true
  def handle_call(:reset, _from, state) do
    new_state = %{state | tokens: state.max_tokens}
    {:reply, :ok, new_state}
  end
  
  @impl true
  def handle_info(:refill, state) do
    state = refill_tokens(state)
    Process.send_after(self(), :refill, state.refill_interval)
    {:noreply, state}
  end
  
  # Private functions
  
  defp ensure_bucket_exists(key, config) do
    case Registry.lookup(@registry, key) do
      [{pid, _}] ->
        pid
      [] ->
        case DynamicSupervisor.start_child(
          @supervisor,
          {__MODULE__, key: key, config: config}
        ) do
          {:ok, pid} -> pid
          {:error, {:already_started, pid}} -> pid
        end
    end
  end
  
  defp refill_tokens(state) do
    now = System.monotonic_time(:millisecond)
    time_passed = now - state.last_refill
    
    if time_passed >= state.refill_interval do
      tokens_to_add = (time_passed / state.refill_interval) * state.refill_rate
      new_tokens = min(state.tokens + tokens_to_add, state.max_tokens)
      
      :telemetry.execute(
        [:vsm_rate_limiter, :bucket, :refill],
        %{tokens_added: tokens_to_add, tokens: new_tokens},
        %{key: state.key}
      )
      
      %{state | tokens: new_tokens, last_refill: now}
    else
      state
    end
  end
  
  defp calculate_refill_interval(:requests_per_second), do: 1_000
  defp calculate_refill_interval(:requests_per_minute), do: 1_000
  defp calculate_refill_interval(:requests_per_hour), do: 60_000
  
  defp calculate_refill_rate(limit, :requests_per_second), do: limit
  defp calculate_refill_rate(limit, :requests_per_minute), do: limit / 60
  defp calculate_refill_rate(limit, :requests_per_hour), do: limit / 60
  
  defp via_tuple(key) do
    {:via, Registry, {@registry, key}}
  end
end