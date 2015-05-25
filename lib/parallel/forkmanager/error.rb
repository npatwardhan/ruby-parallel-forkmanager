module Parallel
  class ForkManager
    # All of parallel forkmanager's internal errors should inherit from
    # Parallel::ForkManager::Error.
    Error = Class.new(RuntimeError)

    UnknownSerializerError = Class.new(Error)
  end
end
