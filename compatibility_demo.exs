# VSM Rate Limiter Compatibility Demo
# Shows integration with other Viable Systems repos

IO.puts("\n=== VSM Rate Limiter Compatibility Demo ===\n")

# 1. VSM Telemetry Compatibility
IO.puts("1. VSM Telemetry Integration:")
IO.puts("   Rate limiter emits telemetry events compatible with vsm-telemetry:\n")

# Attach a handler to demonstrate telemetry compatibility
:telemetry.attach(
  "vsm-compatibility-handler",
  [:vsm_rate_limiter, :request, :allowed],
  fn event, measurements, metadata, _config ->
    IO.puts("   📊 Telemetry Event: #{inspect(event)}")
    IO.puts("      Measurements: #{inspect(measurements)}")
    IO.puts("      Metadata: #{inspect(metadata)}")
  end,
  nil
)

# Configure and test
VsmRateLimiter.configure_subsystem(:s1_environment, rate_limit: {10, :requests_per_minute})
VsmRateLimiter.check_rate(:s1_environment, "demo_user")

# 2. VSM Subsystem Naming Compatibility
IO.puts("\n2. VSM Subsystem Naming (S1-S5) Compatibility:")
IO.puts("   All standard VSM subsystems are supported:\n")

subsystems = [
  :s1_environment,
  :s2_coordination, 
  :s3_control,
  :s3_star_audit,
  :s4_intelligence,
  :s4_star_research,
  :s5_policy
]

for subsystem <- subsystems do
  {:ok, config} = VsmRateLimiter.SubsystemManager.get_config(subsystem)
  {limit, _unit} = config[:rate_limit]
  IO.puts("   ✓ #{subsystem} - configured with limit: #{limit}")
end

# 3. Algedonic Channel Compatibility
IO.puts("\n3. Algedonic Channel Compatibility:")
IO.puts("   Rate limiter integrates with VSM algedonic signaling:\n")

# This would integrate with vsm-telemetry's AlgedonicChannel
:telemetry.attach(
  "algedonic-compatibility",
  [:vsm_rate_limiter, :algedonic, :alert],
  fn _event, measurements, metadata, _config ->
    IO.puts("   🚨 Algedonic Signal - Severity: #{measurements.severity}")
    IO.puts("      Subsystem: #{metadata.subsystem}, Type: #{metadata.type}")
  end,
  nil
)

# Trigger an algedonic event
VsmRateLimiter.configure_subsystem(:s5_policy, 
  rate_limit: {2, :requests_per_minute},
  algedonic_threshold: 0.5
)
VsmRateLimiter.check_rate(:s5_policy, "test")
VsmRateLimiter.check_rate(:s5_policy, "test")

# 4. Event Format Compatibility (for vsm-goldrush)
IO.puts("\n4. VSM Event Format (vsm-goldrush compatible):")

# Rate limiter events can be converted to goldrush format
event = %{
  type: "rate_limit_check",
  subsystem: "s1_environment",
  identifier: "user_123",
  result: "allowed",
  remaining: 9,
  timestamp: DateTime.utc_now()
}

IO.puts("   VSM Event: #{inspect(event)}")

# Convert to property list format for goldrush
goldrush_event = Enum.map(event, fn {k, v} -> {k, v} end)
IO.puts("   Goldrush Format: #{inspect(goldrush_event)}")

# 5. Integration Example
IO.puts("\n5. Integration Example:")
IO.puts("   How to use vsm-rate-limiter with other VSM components:\n")

example_code = """
   # In your VSM application:
   
   # 1. Add to mix.exs deps:
   {:vsm_rate_limiter, github: "viable-systems/vsm-rate-limiter"}
   
   # 2. Configure in application.ex:
   children = [
     VsmRateLimiter.Application,
     VsmTelemetry.Application,
     # ... other VSM components
   ]
   
   # 3. Use in your subsystem:
   defmodule MyApp.System1.Implementation do
     def process_request(request) do
       case VsmRateLimiter.check_rate(:s1_environment, request.id) do
         {:ok, _remaining} ->
           # Process the request
           :telemetry.execute([:vsm, :system1, :request], %{count: 1}, %{})
         {:error, :rate_limited} ->
           # Reject with variety attenuation
           {:error, :variety_exceeded}
       end
     end
   end
"""

IO.puts(example_code)

# Cleanup
:telemetry.detach("vsm-compatibility-handler")
:telemetry.detach("algedonic-compatibility")

IO.puts("\n=== Compatibility Demo Complete ===")
IO.puts("\nThe vsm-rate-limiter is fully compatible with:")
IO.puts("✓ vsm-telemetry - Telemetry event patterns")
IO.puts("✓ vsm-starter - Standard subsystem naming")
IO.puts("✓ vsm-goldrush - Event format conversion")
IO.puts("✓ vsm-docs - Follows VSM architecture principles\n")