module Parallel
  class ForkManager
    # This class lets us build a dummy exit status which can be used where we
    # expect a Process::Status.
    class DummyProcessStatus
      def initialize(exitstatus = 0)
        @exitstatus = (exitstatus & 0x37)
      end

      attr_reader :exitstatus

      def stopsig
        nil
      end

      def coredump?
        false
      end
    end
  end
end
