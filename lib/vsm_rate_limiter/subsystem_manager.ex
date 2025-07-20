defmodule VsmRateLimiter.SubsystemManager do
  @moduledoc """
  Manages VSM subsystem configurations for rate limiting.
  
  Each VSM subsystem can have its own rate limiting configuration,
  including different limits, time windows, and algedonic thresholds.
  """
  
  use GenServer
  require Logger
  
  @vsm_subsystems [
    :s1_environment,
    :s2_coordination,
    :s3_control,
    :s3_star_audit,
    :s4_intelligence,
    :s4_star_research,
    :s5_policy
  ]
  
  defstruct configs: %{}
  
  # Client API
  
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  @doc """
  Configure a VSM subsystem with rate limiting parameters.
  """
  def configure(subsystem, opts) when subsystem in @vsm_subsystems do
    GenServer.call(__MODULE__, {:configure, subsystem, opts})
  end
  
  def configure(subsystem, _opts) do
    {:error, {:invalid_subsystem, subsystem}}
  end
  
  @doc """
  Get configuration for a subsystem.
  """
  def get_config(subsystem) do
    GenServer.call(__MODULE__, {:get_config, subsystem})
  end
  
  @doc """
  List all configured subsystems.
  """
  def list_subsystems do
    GenServer.call(__MODULE__, :list_subsystems)
  end
  
  @doc """
  Apply variety attenuation based on current system load.
  """
  def apply_variety_attenuation(subsystem, base_config) do
    GenServer.call(__MODULE__, {:apply_variety_attenuation, subsystem, base_config})
  end
  
  # Server callbacks
  
  @impl true
  def init(_opts) do
    # Initialize with default configurations
    default_configs = Enum.into(@vsm_subsystems, %{}, fn subsystem ->
      {subsystem, default_config_for(subsystem)}
    end)
    
    {:ok, %__MODULE__{configs: default_configs}}
  end
  
  @impl true
  def handle_call({:configure, subsystem, opts}, _from, state) do
    config = Keyword.merge(state.configs[subsystem] || [], opts)
    configs = Map.put(state.configs, subsystem, config)
    
    Logger.info("Configured VSM subsystem #{subsystem} with: #{inspect(config)}")
    
    {:reply, :ok, %{state | configs: configs}}
  end
  
  @impl true
  def handle_call({:get_config, subsystem}, _from, state) do
    case Map.get(state.configs, subsystem) do
      nil -> {:reply, {:error, :not_configured}, state}
      config -> {:reply, {:ok, config}, state}
    end
  end
  
  @impl true
  def handle_call(:list_subsystems, _from, state) do
    subsystems = Map.keys(state.configs)
    {:reply, subsystems, state}
  end
  
  @impl true
  def handle_call({:apply_variety_attenuation, subsystem, base_config}, _from, state) do
    # Apply VSM variety attenuation principles
    attenuated_config = calculate_attenuated_config(subsystem, base_config, state)
    {:reply, attenuated_config, state}
  end
  
  # Private functions
  
  defp default_config_for(subsystem) do
    base_config = [
      adapter: :token_bucket,
      algedonic_threshold: 0.8
    ]
    
    # Different default rate limits based on VSM subsystem characteristics
    rate_limit = case subsystem do
      :s1_environment ->
        # Environment scanning - higher volume allowed
        {1000, :requests_per_minute}
      
      :s2_coordination ->
        # Coordination - moderate volume
        {500, :requests_per_minute}
      
      :s3_control ->
        # Operational control - balanced
        {300, :requests_per_minute}
      
      :s3_star_audit ->
        # Audit function - lower volume, more critical
        {100, :requests_per_minute}
      
      :s4_intelligence ->
        # Intelligence gathering - moderate to high
        {400, :requests_per_minute}
      
      :s4_star_research ->
        # Research & development - lower volume
        {200, :requests_per_minute}
      
      :s5_policy ->
        # Policy decisions - lowest volume, highest importance
        {50, :requests_per_minute}
    end
    
    Keyword.put(base_config, :rate_limit, rate_limit)
  end
  
  defp calculate_attenuated_config(subsystem, base_config, _state) do
    # Implement Ashby's Law of Requisite Variety
    # The variety of the controller must match the variety of the system
    
    current_load = estimate_system_load()
    subsystem_priority = get_subsystem_priority(subsystem)
    
    {base_limit, unit} = Keyword.get(base_config, :rate_limit, {100, :requests_per_minute})
    
    # Attenuate based on system load and subsystem priority
    attenuation_factor = calculate_attenuation_factor(current_load, subsystem_priority)
    
    attenuated_limit = round(base_limit * attenuation_factor)
    
    # Update config with attenuated limit
    Keyword.put(base_config, :rate_limit, {attenuated_limit, unit})
  end
  
  defp estimate_system_load do
    # In a real implementation, this would query system metrics
    # For now, return a mock value between 0.0 and 1.0
    :rand.uniform()
  end
  
  defp get_subsystem_priority(subsystem) do
    # VSM hierarchy priorities (higher number = higher priority)
    case subsystem do
      :s5_policy -> 5       # Highest - policy decisions
      :s4_intelligence -> 4 # Intelligence for policy
      :s4_star_research -> 3
      :s3_star_audit -> 4   # Audit is critical
      :s3_control -> 3      # Operational control
      :s2_coordination -> 2 # Coordination
      :s1_environment -> 1  # Environment sensing
    end
  end
  
  defp calculate_attenuation_factor(load, priority) do
    # Higher priority subsystems get less attenuation under load
    # Load: 0.0 (no load) to 1.0 (full load)
    # Priority: 1 (lowest) to 5 (highest)
    
    base_factor = 1.0 - (load * 0.5)  # Max 50% reduction under full load
    priority_bonus = (priority - 1) * 0.1  # Up to 40% bonus for priority 5
    
    min(1.0, base_factor + priority_bonus)
  end
end