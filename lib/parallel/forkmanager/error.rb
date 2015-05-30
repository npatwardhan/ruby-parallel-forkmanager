module Parallel
  class ForkManager
    ##
    # The class from which all of {Parallel::ForkManager}'s error exceptions
    # should inherit.  This makes rescuing them easier.
    class Error < RuntimeError; end

    ##
    # Raised when an unknown type of serialization is requested.
    class UnknownSerializerError < Error; end

    ##
    # Raised when the specified temporary directory isn't a directory.
    class MissingTempDirError < Error; end

    ##
    # Raised when we call +start+ in a child process.
    class AttemptedStartInChildProcessError; end
  end
end
