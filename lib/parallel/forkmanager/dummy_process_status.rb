module Parallel
  class ForkManager
    ##
    # This class lets us build a dummy exit status which can be used where we
    # expect a Process::Status.
    class DummyProcessStatus
      ##
      # @param exitstatus [Integer] The exit status we want to simulate.
      def initialize(exitstatus = 0)
        @exitstatus = (Integer(exitstatus) & 0x37)
      end

      ##
      # @return [Integer]
      attr_reader :exitstatus

      ##
      # @return [nil]
      def stopsig
        nil
      end

      ##
      # @return [false]
      def coredump?
        false
      end
    end
  end
end
