defmodule VsmRateLimiterTest do
  use ExUnit.Case
  doctest VsmRateLimiter

  setup do
    # Start the application if not already started
    {:ok, _} = Application.ensure_all_started(:vsm_rate_limiter)
    
    # Reset any existing configurations
    on_exit(fn ->
      # Cleanup after tests
    end)
    
    :ok
  end

  describe "configure_subsystem/2" do
    test "configures valid VSM subsystem" do
      assert :ok = VsmRateLimiter.configure_subsystem(:s1_environment, 
        rate_limit: {50, :requests_per_minute},
        algedonic_threshold: 0.9
      )
    end

    test "rejects invalid subsystem" do
      assert {:error, {:invalid_subsystem, :invalid}} = 
        VsmRateLimiter.configure_subsystem(:invalid, [])
    end
  end

  describe "check_rate/2" do
    setup do
      VsmRateLimiter.configure_subsystem(:s1_environment,
        rate_limit: {10, :requests_per_minute}
      )
      :ok
    end

    test "allows requests within rate limit" do
      assert {:ok, remaining} = VsmRateLimiter.check_rate(:s1_environment, "test_user")
      assert remaining > 0
    end

    test "rejects requests exceeding rate limit" do
      # Consume all tokens
      for _ <- 1..10 do
        VsmRateLimiter.check_rate(:s1_environment, "test_user_2")
      end
      
      # Next request should be rejected
      assert {:error, :rate_limited} = 
        VsmRateLimiter.check_rate(:s1_environment, "test_user_2")
    end

    test "different identifiers have separate limits" do
      # User 1
      assert {:ok, _} = VsmRateLimiter.check_rate(:s1_environment, "user_1")
      
      # User 2 should still have full quota
      assert {:ok, remaining} = VsmRateLimiter.check_rate(:s1_environment, "user_2")
      assert remaining == 9
    end
  end

  describe "get_status/2" do
    test "returns status for existing rate limit" do
      VsmRateLimiter.check_rate(:s1_environment, "status_test")
      status = VsmRateLimiter.get_status(:s1_environment, "status_test")
      
      assert %{exists: true} = status
    end
  end

  describe "reset/2" do
    test "resets rate limit for identifier" do
      # Consume some tokens
      VsmRateLimiter.check_rate(:s1_environment, "reset_test")
      VsmRateLimiter.check_rate(:s1_environment, "reset_test")
      
      # Reset
      assert :ok = VsmRateLimiter.reset(:s1_environment, "reset_test")
      
      # Should have full quota again
      status = VsmRateLimiter.get_status(:s1_environment, "reset_test")
      assert status.exists == false or status.tokens == status.max_tokens
    end
  end

  describe "adapter switching" do
    test "can switch between adapters" do
      assert :ok = VsmRateLimiter.use_adapter(:ex_rated)
      assert :ok = VsmRateLimiter.use_adapter(:hammer)
      assert :ok = VsmRateLimiter.use_adapter(:token_bucket)
    end
  end
end