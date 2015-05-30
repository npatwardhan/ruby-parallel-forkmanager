# We don't need documentation for the classes for minitest classes
#
# rubocop:disable Style/Documentation
require "minitest_helper"

module TestParallelForkManager
  class TestSimpleCase < Minitest::Test
    PIDS = [123, 456]

    def test_life_cycle
      pi = MiniTest::Mock.new
      pfm = Parallel::ForkManager.new(1, "process_interface" => pi)

      pi.expect(:fork,         PIDS[0])
      pi.expect(:waitpid,      PIDS[0], [PIDS[0], 1])
      pi.expect(:child_status, Parallel::ForkManager::DummyProcessStatus.new(0))
      pi.expect(:fork,         PIDS[1])
      pi.expect(:waitpid,      PIDS[1], [PIDS[1], 1])
      pi.expect(:child_status, Parallel::ForkManager::DummyProcessStatus.new(0))

      %w(one two).each do |item|
        pfm.start(item) && next
        pfm.finish(0)
      end

      pfm.wait_all_children

      assert pi.verify
    end
  end
end
