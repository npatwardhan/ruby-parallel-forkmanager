# We don't need documentation for the classes for minitest classes
#
# rubocop:disable Style/Documentation
require "minitest_helper"

module TestParallelForkManager
  # This depends on the implementation of the code to wait for child processes
  # in the order they were forked.  It should be good enough to detect changes
  # in the calls to the process interface if refactoring goes awry.  If your
  # changes were intended to change the behaviour then this test might be better
  # deleted or modified.
  class TestLessSimpleCase < Minitest::Test
    PIDS = [10, 11, 12]
    POOL_SIZE = 2

    attr_reader :pi, :pfm, :running_pids

    def test_more_processes_than_allowed
      @pi = MiniTest::Mock.new
      @pfm = Parallel::ForkManager.new(POOL_SIZE, "process_interface" => @pi)
      @running_pids = []

      start_initial_processes
      start_third_process
      wait_for_children
    end

    def start_initial_processes
      start_process(PIDS[0], "one")
      start_process(PIDS[1], "two")
    end

    def start_third_process
      # When we try to start the third process it'll loop through the
      # two "running" processes.  Check that it goes around at least
      # once, simulating the processes still running...
      still_running([PIDS[0], PIDS[1]])

      # On the second run around the loop we'll pretend the second
      # process has finished, making way for the third to start...
      finished_running(PIDS[1], 0)

      start_process(PIDS[2], "three")
    end

    def wait_for_children
      finished_running(PIDS[2], 0)
      finished_running(PIDS[0], 0)

      pfm.wait_all_children
      assert pi.verify
    end

    # utilities to make the tests more understandable.
    def still_running(pids)
      pids.each do |pid|
        pi.expect(:waitpid, nil, [pid, Process::WNOHANG])
      end
    end

    def finished_running(finished_pid, return_code)
      running_pids.each do |running_pid|
        waitpid_return = running_pid == finished_pid ? finished_pid : nil
        pi.expect(:waitpid, waitpid_return, [running_pid, Process::WNOHANG])
      end
      pi.expect(:child_status, return_code)
      running_pids.delete finished_pid
    end

    def start_process(pid, identifier)
      will_fork(pid)
      assert_equal pid, pfm.start(identifier)
      assert pi.verify
    end

    def will_fork(pid)
      # This just assumes all the processes are still running
      still_running running_pids
      pi.expect(:fork, pid)
      running_pids << pid
    end
  end
end
