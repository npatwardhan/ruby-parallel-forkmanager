module Parallel
  class ForkManager
    # All of parallel forkmanager's internal errors should inherit from
    # Parallel::ForkManager::Error.
    class Error < RuntimeError; end

    class UnknownSerializerError < Error; end
    class MissingTempDirError < Error; end
    class AttemptedStartInChildProcessError; end
  end
end
