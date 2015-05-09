# We don't need documentation for the classes for minitest classes
#
# rubocop:disable Style/Documentation
require "minitest_helper"

module TestParallelForkManager
  class TestDebugMode < Minitest::Test
    MY_PID    = $PID
    IDENT     = "ident"
    EXIT_CODE = 10

    def setup
      @pfm = Parallel::ForkManager.new(0)
    end

    def test_nil_from_start
      assert_nil @pfm.start(IDENT)
    end

    def test_run_on_finish
      pid = error_code = ident = nil

      @pfm.run_on_finish do |p, e, i|
        pid        = p
        error_code = e
        ident      = i
      end

      @pfm.start(IDENT)
      @pfm.finish(EXIT_CODE)

      assert_equal [MY_PID, EXIT_CODE, IDENT], [pid, error_code, ident]
    end

    def test_run_on_start
      pid = ident = nil

      @pfm.run_on_start do |p, i|
        pid   = p
        ident = i
      end

      @pfm.start(IDENT)

      assert_equal [MY_PID, IDENT], [pid, ident]
    end

    def test_run_on_wait
      run_on_wait_called = false

      @pfm.run_on_wait(0.1) { run_on_wait_called = true }

      @pfm.start(IDENT)
      @pfm.finish(EXIT_CODE)
      @pfm.wait_all_children

      refute run_on_wait_called, "run on wait shouldn't be called"
    end
  end
end
