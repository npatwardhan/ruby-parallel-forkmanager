require "English"
require "forwardable"

module Parallel
  # This class defines an interface to fork & waitpid so that there is a good
  # "seam" at which to mock.
  #
  # Parallel::ProcessInterface adds a process_interface attribute and delegates
  # fork, child_status, and waitpid to it as private methods.
  module ProcessInterface
    extend Forwardable

    attr_reader :process_interface
    private :process_interface

    # Not quite sure why fork can't be delegated successfully.
    private def fork(*args, &block)
      process_interface.fork(*args, &block)
    end

    def_delegators :@process_interface, :child_status, :waitpid
    private :child_status, :waitpid

    # A Parallel::ProcessInterface::Instance is something we can delegate to.
    class Instance
      def fork(*args, &block)
        Kernel.fork(*args, &block)
      end

      def waitpid(*args)
        Process.waitpid(*args)
      end

      def child_status
        $CHILD_STATUS
      end
    end
  end
end
