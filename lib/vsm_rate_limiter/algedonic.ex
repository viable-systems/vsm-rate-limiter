defmodule VsmRateLimiter.Algedonic do
  @moduledoc """
  Algedonic system for critical alerts in VSM rate limiting.
  
  Implements pain/pleasure signals for the system to respond to critical
  rate limiting events and threshold breaches.
  """
  
  use GenServer
  require Logger
  
  @type alert_type :: :high_usage | :rate_limit_exceeded | :subsystem_overload | :critical_failure
  @type severity :: :low | :medium | :high | :critical
  
  defstruct [
    alerts: [],
    handlers: [],
    thresholds: %{}
  ]
  
  # Client API
  
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  @doc """
  Trigger an algedonic alert.
  """
  def trigger_alert(subsystem, alert_type, metadata \\ %{}) do
    GenServer.cast(__MODULE__, {:trigger_alert, subsystem, alert_type, metadata})
  end
  
  @doc """
  Register a handler for algedonic alerts.
  """
  def register_handler(handler_fun) when is_function(handler_fun, 3) do
    GenServer.call(__MODULE__, {:register_handler, handler_fun})
  end
  
  @doc """
  Set threshold for automatic alerts.
  """
  def set_threshold(subsystem, threshold_type, value) do
    GenServer.call(__MODULE__, {:set_threshold, subsystem, threshold_type, value})
  end
  
  @doc """
  Get recent alerts.
  """
  def get_alerts(limit \\ 10) do
    GenServer.call(__MODULE__, {:get_alerts, limit})
  end
  
  # Server callbacks
  
  @impl true
  def init(_opts) do
    state = %__MODULE__{
      alerts: [],
      handlers: [&default_handler/3],
      thresholds: %{}
    }
    
    {:ok, state}
  end
  
  @impl true
  def handle_cast({:trigger_alert, subsystem, alert_type, metadata}, state) do
    alert = build_alert(subsystem, alert_type, metadata)
    severity = calculate_severity(alert_type, metadata)
    
    # Log the alert
    log_alert(alert, severity)
    
    # Execute telemetry
    :telemetry.execute(
      [:vsm_rate_limiter, :algedonic, :alert],
      %{severity: severity_to_number(severity)},
      %{subsystem: subsystem, type: alert_type}
    )
    
    # Call all registered handlers
    Enum.each(state.handlers, fn handler ->
      try do
        handler.(alert, severity, metadata)
      rescue
        e ->
          Logger.error("Algedonic handler failed: #{inspect(e)}")
      end
    end)
    
    # Store alert in state (keep last 100)
    alerts = [alert | state.alerts] |> Enum.take(100)
    
    {:noreply, %{state | alerts: alerts}}
  end
  
  @impl true
  def handle_call({:register_handler, handler_fun}, _from, state) do
    {:reply, :ok, %{state | handlers: [handler_fun | state.handlers]}}
  end
  
  @impl true
  def handle_call({:set_threshold, subsystem, threshold_type, value}, _from, state) do
    thresholds = Map.put(state.thresholds, {subsystem, threshold_type}, value)
    {:reply, :ok, %{state | thresholds: thresholds}}
  end
  
  @impl true
  def handle_call({:get_alerts, limit}, _from, state) do
    alerts = Enum.take(state.alerts, limit)
    {:reply, alerts, state}
  end
  
  # Private functions
  
  defp build_alert(subsystem, alert_type, metadata) do
    %{
      id: generate_alert_id(),
      timestamp: DateTime.utc_now(),
      subsystem: subsystem,
      type: alert_type,
      metadata: metadata
    }
  end
  
  defp calculate_severity(alert_type, metadata) do
    case alert_type do
      :critical_failure -> :critical
      :subsystem_overload -> :high
      :rate_limit_exceeded -> :medium
      :high_usage ->
        usage_ratio = Map.get(metadata, :usage_ratio, 0)
        cond do
          usage_ratio >= 0.95 -> :high
          usage_ratio >= 0.9 -> :medium
          true -> :low
        end
      _ -> :low
    end
  end
  
  defp severity_to_number(:low), do: 1
  defp severity_to_number(:medium), do: 2
  defp severity_to_number(:high), do: 3
  defp severity_to_number(:critical), do: 4
  
  defp log_alert(alert, severity) do
    message = "Algedonic Alert [#{severity}] - Subsystem: #{alert.subsystem}, Type: #{alert.type}"
    
    case severity do
      :critical -> Logger.error(message, alert: alert)
      :high -> Logger.warning(message, alert: alert)
      :medium -> Logger.warning(message, alert: alert)
      :low -> Logger.info(message, alert: alert)
    end
  end
  
  defp default_handler(alert, severity, _metadata) do
    # Default handler implementation
    # In production, this could send notifications, trigger circuit breakers, etc.
    case severity do
      :critical ->
        Logger.error("CRITICAL ALGEDONIC SIGNAL: System requires immediate attention", alert: alert)
        # Could trigger emergency procedures here
      :high ->
        Logger.warning("High severity algedonic signal detected", alert: alert)
      _ ->
        :ok
    end
  end
  
  defp generate_alert_id do
    :crypto.strong_rand_bytes(16) |> Base.encode16(case: :lower)
  end
end