# VSM Rate Limiter Demo

IO.puts("\n=== VSM Rate Limiter Demo ===\n")

# 1. Configure a VSM subsystem
IO.puts("1. Configuring S1 Environment subsystem...")
VsmRateLimiter.configure_subsystem(:s1_environment, 
  rate_limit: {5, :requests_per_minute},
  algedonic_threshold: 0.8
)
IO.puts("   ✓ Configured with 5 requests per minute limit\n")

# 2. Make some requests
IO.puts("2. Making requests as user_123...")
for i <- 1..7 do
  case VsmRateLimiter.check_rate(:s1_environment, "user_123") do
    {:ok, remaining} ->
      IO.puts("   Request #{i}: ✓ Allowed (#{remaining} remaining)")
    {:error, :rate_limited} ->
      IO.puts("   Request #{i}: ✗ Rate limited!")
  end
  Process.sleep(100)
end

# 3. Check status
IO.puts("\n3. Checking status...")
status = VsmRateLimiter.get_status(:s1_environment, "user_123")
IO.inspect(status, label: "   Status")

# 4. Different user has separate limit
IO.puts("\n4. Different user (user_456) has separate limit...")
case VsmRateLimiter.check_rate(:s1_environment, "user_456") do
  {:ok, remaining} ->
    IO.puts("   ✓ Allowed (#{remaining} remaining)")
  {:error, :rate_limited} ->
    IO.puts("   ✗ Rate limited!")
end

# 5. Test different adapters
IO.puts("\n5. Testing different adapters...")

# Token Bucket (default)
IO.puts("   a) Token Bucket (default):")
VsmRateLimiter.use_adapter(:token_bucket)
{:ok, _} = VsmRateLimiter.check_rate(:s2_coordination, "test_user")
IO.puts("      ✓ Token bucket working")

# ExRated
IO.puts("   b) ExRated adapter:")
VsmRateLimiter.use_adapter(:ex_rated)
{:ok, _} = VsmRateLimiter.check_rate(:s2_coordination, "test_user")
IO.puts("      ✓ ExRated working")

# Hammer
IO.puts("   c) Hammer adapter:")
VsmRateLimiter.use_adapter(:hammer)
{:ok, _} = VsmRateLimiter.check_rate(:s2_coordination, "test_user")
IO.puts("      ✓ Hammer working")

# 6. Test algedonic alerts
IO.puts("\n6. Testing algedonic alerts...")
VsmRateLimiter.use_adapter(:token_bucket)

# Register alert handler
VsmRateLimiter.Algedonic.register_handler(fn alert, severity, _metadata ->
  IO.puts("   🚨 Algedonic Alert: #{severity} - #{inspect(alert.type)}")
end)

# Configure tight limit to trigger alert
VsmRateLimiter.configure_subsystem(:s5_policy, 
  rate_limit: {2, :requests_per_minute},
  algedonic_threshold: 0.5
)

# Make requests to trigger alert
for _i <- 1..2 do
  VsmRateLimiter.check_rate(:s5_policy, "critical_user")
end

# 7. Show VSM subsystem hierarchy
IO.puts("\n7. VSM Subsystem Hierarchy:")
subsystems = VsmRateLimiter.SubsystemManager.list_subsystems()
for subsystem <- Enum.sort(subsystems) do
  {:ok, config} = VsmRateLimiter.SubsystemManager.get_config(subsystem)
  {limit, unit} = Keyword.get(config, :rate_limit)
  IO.puts("   #{subsystem}: #{limit} #{unit}")
end

IO.puts("\n=== Demo Complete ===\n")