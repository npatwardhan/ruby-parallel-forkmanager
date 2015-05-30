require "English"
require "tmpdir"
require "yaml"

require_relative "forkmanager/version"
require_relative "forkmanager/process_interface"
require_relative "forkmanager/serializer"
require_relative "forkmanager/dummy_process_status"

##
# This module provides a namespace.
module Parallel
  ##
  # This class provides a higher level interface to +fork+, allowing you to
  # limit the number of child processes spawned and it provides a mechanism for
  # child processes to return data structures to the parent.
  class ForkManager
    include Parallel::ForkManager::ProcessInterface

    ##
    # Instantiate a Parallel::ForkManager object. You must specify the maximum
    # number of children to fork off. If you specify 0 (zero), then no children
    # will be forked.  This is intended for debugging purposes.
    #
    # The optional second parameter, params, is only used if you want to customize
    # the behavior that children will use to send back some data (see Retrieving
    # Data Structures below) to the parent.  The following values are currently
    # accepted for params (and their meanings):
    # - params['tempdir'] represents the location of the temporary directory where serialized data structures will be stored.
    # - params['serialize_as'] represents how the data will be serialized.
    #
    # XXX: Not quite true at the moment, debug is set to 0 if no params are
    # provided, and the serialization isn't set.
    #
    # If params has not been provided, the following values are set:
    # - @debug is set to non-zero to provide debugging messages.  Default is 0.
    # - @tempdir is set to Dir.tmpdir() (likely defaults to /tmp).
    #
    # NOTE NOTE NOTE: If you set tempdir to a directory that does not exist,
    # Parallel::ForkManager will <em>not</em> create this directory for you
    # and new() will exit!
    #
    # @param max_procs[Integer] maximum number of concurrent child processes.
    # @param params[Hash] configuration parameters.
    def initialize(max_procs = 0, params = {})
      check_ruby_version
      setup_instance_variables(max_procs, params)

      # Always provide debug information if our max processes are zero!
      if @max_procs.zero?
        puts "Zero processes have been specified so we will not fork and will proceed in debug mode!"
        puts "in initialize #{max_procs}!"
        puts "Will use tempdir #{@tempdir}"
      end

      # Appetite for Destruction.
      ObjectSpace.define_finalizer(self, self.class._finalize)
    end

    ##
    # This finalizer is not meant to be called manually, it cleans up temporary
    # files which were used to return serialized data from the children.
    def self._finalize
      proc do
        Dir.foreach(tempdir) do |file_name|
          prefix = "Parallel-ForkManager-#{parent_pid}-"
          next unless file_name.start_with prefix
          File.unlink("#{tempdir}/#{file_name}")
        end
      end
    end

    attr_reader :max_procs

    ##
    # start("string") "puts the fork in Parallel::ForkManager" -- as start() does
    # the fork().  start() returns the pid of the child process for the parent,
    # and 0 for the child process.  If you set the 'processes' parameter for the
    # constructor to 0, then, assuming you're in the child process, pm.start()
    # simply returns 0.
    #
    # start("string") takes an optional "string" argument to use as a process
    # identifier.  It is used by the "run_on_finish" callback for identifying
    # the finished process.  See run_on_finish() for more information.
    #
    # For example:
    #
    #   my_ident = "webwacker-1.0"
    #   pm.start(my_ident)
    #
    # start("string") { block } takes an optional block parameter
    # that tells the ForkManager to follow Ruby fork() semantics for blocks.
    # For example:
    #
    #   my_ident = "webwacker-1.0"
    #   pm.start(my_ident) {
    #       print "As easy as "
    #       [1,2,3].each {
    #           |i|
    #           print i, "... "
    #       }
    #   }
    #
    # start("string", arg1, arg2, ... , argN) { block } requires a block parameter
    # that tells the ForkManager to follow Ruby fork() semantics for blocks.  Like
    # start("string"), "string" is an optional argument to use as a process
    # identifier and is used by the "run_on_finish" callback for identifying
    # the finished process.  For example:
    #
    #   my_ident = "webwacker-1.0"
    #   pm.start(my_ident, 1, 2, 3) {
    #       |*my_args|
    #       unless my_args.empty?
    #           print "As easy as "
    #           my_args.each {
    #               |i|
    #               print i, "... "
    #           }
    #       end
    #   }
    #
    # <em>NOTE NOTE NOTE: when you use start("string") with an optional block
    # parameter, the code in your block <em>must</em> explicitly exit non-zero
    # if you are using callbacks with the ForkManager (e.g. run_on_finish).</em>
    # This is because fork(), when run with a block parameter, terminates the
    # subprocess with a status of 0 by default.  If your block fails to exit
    # non-zero, *all* of your exit_code(s) will be zero regardless of any value
    # you might have passed to finish(...).
    #
    # To accommodate this behavior of fork and blocks, you can do
    # something like the following:
    #
    #   my_urls = [ ... some list of urls here ... ]
    #   my_ident = "webwacker-1.0"
    #
    #   my_urls.each {
    #       |my_url|
    #       pm.start(my_ident) {
    #           my_status = get_some_url(my_url)
    #           if my_status.to_i == 200
    #               exit 0
    #           else
    #               exit 255
    #       }
    #   }
    #
    #   ... etc ...
    #

    def start(identification = nil, *args, &run_block)
      fail AttemptedStartInChildProcessError if in_child

      while @max_procs.nonzero? && @processes.length >= @max_procs
        on_wait
        arg = (defined? @on_wait_period && !@on_wait_period.nil?) ? Process::WNOHANG : nil
        wait_one_child(arg)
      end

      wait_children

      if @max_procs.nonzero?
        if block_given?
          fail "start(...) wrong number of args" if run_block.arity >= 0 && args.size != run_block.arity
          @has_block = true
          pid = (!args.empty?) ?
            fork { run_block.call(*args); } :
            fork { run_block.call(); }
        else
          fail "start(...) args given but block is empty!" unless args.empty?

          pid = fork
        end
        fail "Cannot fork #{$ERROR_INFO}" unless defined? pid

        if pid.nil?
          self.in_child = true
        else
          @processes[pid] = identification
          on_start(pid, identification)
        end

        return pid
      else
        @processes[$PID] = identification
        on_start($PID, identification)

        return nil
      end
    end

    #
    # finish(exit_code, [data_structure]) -- exit_code is optional
    #
    # finish() closes the child process by exiting and accepts an optional exit
    # code (default exit code is 0) which can be retrieved in the parent via
    # callback.  If you're running the program in debug mode (max_proc == 0),
    # this method just calls the callback.
    #
    # If <em>data_structure</em> is provided, then <em>data structure</em> is
    # serialized and passed to the parent process. See <em>Retrieving Data
    # Structures</em> in the next section for more info.  For example:
    #
    #    %w{Fred Wilma Ernie Bert Lucy Ethel Curly Moe Larry}.each {
    #        |person|
    #        # pm.start(...) here
    #
    #        # ... etc ...
    #
    #        # Pass along data structure to finish().
    #        pm.finish(0, {'person' => person})
    #    }
    #
    #
    # === Retrieving Data Structures
    #
    # The ability for the parent to retrieve data structures from child processes
    # was adapted to Parallel::ForkManager 1.5.0 (and newer) from Perl Parallel::ForkManager.
    # This functionality was originally introduced in Perl Parallel::ForkManager
    # 0.7.6.
    #
    # Each child process may optionally send 1 data structure back to the parent.
    # By data structure, we mean a a string, hash, or array. The contents of the
    # data structure are written out to temporary files on disk using the Marshal
    # dump() method.  This data structure is then retrieved from within the code
    # you send to the run_on_finish callback.
    #
    # NOTE NOTE NOTE: Only serialization with Marshal and yaml are supported at
    # this time.  Future versions of Parallel::ForkManager <em>may</em> support
    # expanded functionality!
    #
    # There are 2 steps involved in retrieving data structures:
    # 1. The data structure the child wishes to send back to the parent is provided as the second argument to the finish() call. It is up to the child to decide whether or not to send anything back to the parent.
    # 2. The data structure is retrieved using the callback provided in the run_on_finish() method.
    #
    # Data structure retrieval is <em>not</em> the same as returning a data
    # structure from a method call!  The data structure referenced by a given
    # child process is serialized and written out to a file in the type specified
    # earlier in serialize_as.  If serialize_as was not specified earlier, then
    # no serialization will be done.
    #
    # The file is subseqently read back into memory and a new data structure that
    # belongs to the parent process is created.  Therefore it is recommended that
    # you keep the returned structure small in size to mitigate any possible
    # performance penalties.
    #
    def finish(exit_code = 0, data_structure = nil)
      if @has_block
        fail "Do not use finish(...) when using blocks.  Use an explicit exit in your block instead!\n"
      end

      if in_child
        exit_code ||= 0

        unless data_structure.nil?
          @data_structure = data_structure

          the_tempfile = "#{@tempdir}Parallel-ForkManager-#{@parent_pid}-#{$PID}.txt"

          begin
            fail "Unable to serialize data!" unless _serialize_data(the_tempfile)
          rescue => e
            puts "Unable to store #{the_tempfile}: #{e.message}"
            exit 1
          end
        end

        Kernel.exit!(exit_code)
      end

      if @max_procs == 0
        on_finish($PID, exit_code, @processes[$PID], 0, 0)
        @processes.delete($PID)
      end
      0
    end

    # reap_finished_children() / wait_children()
    #
    # This is a non-blocking call to reap children and execute callbacks independent
    # of calls to "start" or "wait_all_children". Use this in scenarios where
    # "start" is called infrequently but you would like the callbacks executed quickly.

    def wait_children
      return if @processes.keys.empty?

      kid = nil
      begin
        begin
          kid = wait_one_child(Process::WNOHANG)
        end while kid > 0 || kid < -1
      rescue Errno::ECHILD
        return
      end
    end

    alias_method :wait_childs, :wait_children # compatibility
    alias_method :reap_finished_children, :wait_children; # behavioral synonym for clarity

    #
    # Probably won't want to call this directly.  Just let wait_all_children(...)
    # make the call for you.
    #
    def wait_one_child(par)
      params = par || 0

      kid = nil
      loop do
        kid = _waitpid(-1, params)
        break if kid.nil? || kid == 0 || kid == -1 # Win32 returns negative PIDs
        redo unless @processes.key?(kid)
        id = @processes.delete(kid)

        # Retrieve child data structure, if any.
        the_retr_data = nil
        the_tempfile = "#{@tempdir}Parallel-ForkManager-#{$PID}-#{kid}.txt"

        begin
          if File.exist?(the_tempfile) && !File.zero?(the_tempfile)
            unless _unserialize_data(the_tempfile)
              fail "Unable to unserialize data!"
            end

            the_retr_data = @data_structure
          end

          File.unlink(the_tempfile) if File.exist?(the_tempfile)
        rescue => e
          print "wait_one_child failed to retrieve object: #{e.message}\n"
          exit 1
        end

        status = child_status
        on_finish(kid, status.exitstatus, id, status.stopsig, status.coredump?, the_retr_data)
        break
      end

      kid ||= 0
      kid
    end

    #
    # wait_all_children() will wait for all the processes which have been
    # forked. This is a blocking wait.
    #
    def wait_all_children
      until @processes.keys.empty?
        on_wait
        arg = (defined? @on_wait_period and !@on_wait_period.nil?) ? Process::WNOHANG : nil
        wait_one_child(arg)
      end
    rescue Errno::ECHILD
      # do nothing.
    end

    alias_method :wait_all_childs, :wait_all_children # compatibility

    #
    # max_procs() -- Returns the maximal number of processes the object will fork.
    #
    attr_reader :max_procs

    #
    # running_procs() -- Returns the pids of the forked processes currently
    # monitored by the Parallel::ForkManager.  Note that children are still
    # reports as running until the fork manager will harvest them, via the
    # next call to start(...) or wait_all_children().
    #
    def running_procs
      @processes.keys
    end

    #
    # is_parent()
    #
    # Returns true if within the parent or false if within the child.
    #
    def is_parent()
      !in_child
    end

    #
    # is_child()
    #
    # Returns true if within the child or false if within the parent.
    #
    def is_child()
      in_child
    end

    #
    # wait_for_available_procs(nbr) -- Wait until 'n' available process slots
    # are available.  If 'n' is not given, defaults to I.
    #
    def wait_for_available_procs(nbr)
      nbr ||= 1

      fail "Number processes '#{nbr}' higher than then max number of processes: #{@max_procs}" if nbr > max_procs

      wait_one_child until (max_procs - running_procs) >= nbr
    end

    #
    # You can define run_on_finish(...) that is called when a child in the parent
    # process when a child is terminated.
    #
    # The parameters of run_on_finish(...) are:
    #
    # - pid of the process, which is terminated
    # - exit code of the program
    # - identification of the process (if provided in the "start" method)
    # - exit signal (0-127: signal name)
    # - core dump (1 if there was core dump at exit)
    # - data structure or nil (see Retrieving Data Structures)
    #
    # As of Parallel::ForkManager 1.2.0 run_on_finish supports a block argument.
    #
    # Example:
    #
    #   pm.run_on_finish {
    #           |pid,exit_code,ident|
    #           print "** PID (#{pid}) for #{ident} exited with code #{exit_code}!\n"
    #   }
    #
    def run_on_finish(code = nil, pid = 0, &my_block)
      if !code.nil? && !my_block.nil?
        fail "run_on_finish: code and block are mutually exclusive options!"
      end

      if !code.nil?
        if code.class.to_s == "Proc" && VERSION >= "1.5.0"
          print "Passing Proc has been deprecated as of Parallel::ForkManager #{VERSION}!\nPlease refer to rdoc about how to change your code!\n"
        end
        @do_on_finish[pid] = code
      elsif !my_block.nil?
        @do_on_finish[pid] = my_block
      end
    rescue TypeError => e
      raise e.message
    end

    #
    # on_finish is a private method and should not be called directly.
    #
    def on_finish(*params)
      pid = params[0]
      code = @do_on_finish[pid] || @do_on_finish[0] or return 0
      begin
        my_argc = code.arity - 1
        if my_argc > 0
          my_params = params[0..my_argc]
        else
          my_params = [params[0]]
        end
        params = my_params
        code.call(*params)
      rescue => e
        raise "on finish failed: #{e.message}!\n"
      end
    end

    #
    # You can define a subroutine which is called when the child process needs
    # to wait for the startup. If period is not defined, then one call is done per
    # child. If period is defined, then code is called periodically and the
    # method waits for "period" seconds betwen the two calls. Note, period can be
    # fractional number also. The exact "period seconds" is not guaranteed,
    # signals can shorten and the process scheduler can make it longer (i.e. on
    # busy systems).
    #
    # No parameters are passed to code on the call.
    #
    # Example:
    #
    # As of Parallel::ForkManager 1.2.0 run_on_wait supports a block argument.
    #
    # Example:
    #   period = 0.5
    #   pm.run_on_wait(period) {
    #           print "** Have to wait for one child ...\n"
    #   }
    #
    #

    def run_on_wait(*params, &block)
      fail "period is required by run_on_wait" unless params.length

      if params.length == 1
        period = params[0]
        fail "period must be of type float!" if period.class.to_s.downcase != "float"
      elsif params.length == 2
        code, period = params
        fail "run_on_wait: Missing or invalid code block!" if code.class.to_s.downcase != "proc"
      else
        fail "run_on_wait: Invalid argument count!"
      end

      @on_wait_period = period
      fail "Wait period must be greater than 0.0!\n" if period == 0

      if !code.nil? && !block.nil?
        fail "run_on_wait: code and block are mutually exclusive arguments!"
      end

      if !code.nil?
        if code.class.to_s == "Proc" && VERSION >= "1.5.0"
          puts "Passing Proc has been deprecated as of Parallel::ForkManager #{VERSION}!\nPlease refer to rdoc about how to change your code!"
        end

        @do_on_wait = code
      elsif !block.nil?
        @do_on_wait = block
      end
    rescue TypeError
      raise "run on wait failed!"
    end

    #
    # on_wait is a private method as it should not be called directly.
    #
    def on_wait
      return unless @do_on_wait.class.name == "Proc"

      @do_on_wait.call
      return unless defined? @on_wait_period && !@on_wait_period.nil?
      #
      # Unfortunately Ruby 1.8 has no concept of 'sigaction',
      # so we're unable to check if a signal handler has
      # already been installed for a given signal.  In this
      # case it's no matter, since we define handler, but yikes.
      #
      Signal.trap("CHLD") do
        -> {}.call if Signal.list["CHLD"].nil?
      end
      IO.select(nil, nil, nil, @on_wait_period)
    end

    #
    # You can define a subroutine which is called when a child is started. It is
    # called after a successful startup of a child in the parent process.
    #
    # The parameters of code are as follows:
    # - pid of the process which has been started
    # - identification of the process (if provided in the "start" method)
    #
    # You can pass a block to run_on_start.
    #
    # Example:
    #
    #   pm.run_on_start() {
    #           |pid,ident|
    #           print "run on start ::: #{ident} (#{pid})\n"
    #       }
    #
    #
    def run_on_start(&block)
      @do_on_start = block unless block.nil?
    rescue TypeError
      raise "run on start failed!\n"
    end

    #
    # on_start() is a private method as it should not be called directly.
    #
    def on_start(*params)
      if @do_on_start.class.name == "Proc"
        my_argc = @do_on_start.arity - 1
        if my_argc > 0
          my_params = params[0..my_argc]
        else
          my_params = params[0]
        end
        params = my_params
        @do_on_start.call(*params)
      end
    rescue
      raise "on_start failed"
    end

    #
    # set_max_procs() allows you to set a new maximum number of children
    # to maintain.
    #
    def set_max_procs(mp=nil)
      @max_procs = mp
    end

    #
    # set_wait_pid_blocking_sleep(seconds) -- Sets the sleep period,
    # in seconds, of the pseudo-blocking calls.  Set to 0 to disable.
    #
    def set_waitpid_blocking_sleep(period)
      @waitpid_blocking_sleep = period
    end

    #
    # waitpid_blocking_sleep() -- Returns the sleep period, in seconds, of the
    # pseudo-blockign calls.  Returns 0 if disabled.
    #
    def waitpid_blocking_sleep
      @waitpid_blocking_sleep
    end

    #
    # _waitpid(...) is a private method as it should not be called directly.
    # It is called automatically by wait_one_child(...).
    #
    def _waitpid(_pid, flag)
      flag ? _waitpid_non_blocking : _waitpid_blocking
    end

    #
    # Private method used internally by _waitpid(...).
    #
    def _waitpid_non_blocking
      running_procs.each do |pid|
        p = waitpid(pid, Process::WNOHANG) || next
        if p == -1
          warn "Child process #{pid} disappeared.  A call to 'waitpid' outside of Parallel::ForkManager might have reaped it."
          # It's gone.  Let's clean the process entry.
          @processes.delete[pid]
        else
          return pid
        end
      end

      0
    end

    #
    # Private method used internally by _waitpid(...).  Simulates a blocking
    # waitpid(...) call.
    #
    def _waitpid_blocking
      # pseudo-blocking
      sleep_period = @waitpid_blocking_sleep
      loop do
        pid = _waitpid_non_blocking
        return pid if pid

        sleep(sleep_period)
      end

      waitpid(-1, 0)
    end

    #
    # _serialize_data is a private method and should not be called directly.
    #
    # Currently supports Marshal.dump() and YAML to serialize data.
    #
    def _serialize_data(store_tempfile)
      return 1 if @serializer.nil?

      File.open(store_tempfile, "wb") do |f|
        f.write(@serializer.serialize(@data_structure))
      end
      return 1

    rescue => e
      raise "Error writing/serializing #{store_tempfile}: #{e.message}"
    end

    #
    # _unserialize_data is a private method and should not be called directly.
    #
    # Currently only supports Marshal.load() to unserialize data.
    #
    def _unserialize_data(store_tempfile)
      return 1 if @serializer.nil?

      data = File.binread(store_tempfile)
      @data_structure = @serializer.deserialize(data)
      return 1

    rescue => e
      # Clean up temp file if it exists.
      # Otherwise we'll have a bunch of 'em laying around.
      #
      File.unlink(store_tempfile) rescue nil # XXX: supress errors from unlink.
      raise "Error reading/deserializing #{store_tempfile}: #{e.message}"
    end

    # private methods
    private :on_start, :on_finish, :on_wait
    private :_waitpid, :_waitpid_non_blocking, :_waitpid_blocking
    private :_serialize_data, :_unserialize_data

    private

    attr_reader :parent_pid
    attr_reader :tempdir
    attr_accessor :in_child

    def setup_instance_variables(max_procs, params)
      @max_procs = max_procs

      # TODO: remove this, it seems to be unused.
      @debug = params.fetch("debug", false)

      @tempdir = params.fetch("tempdir", Dir.tmpdir)
      @tempdir += "/" unless @tempdir.end_with?("/")
      unless File.directory? @tempdir
        fail(MissingTempDirError,
             "#{@tempdir} doesn't exist or is not a directory.")
      end

      @process_interface = params.fetch("process_interface",
                                        ProcessInterface::Instance.new)

      @data_structure = nil
      @processes = {}
      @do_on_finish = {}
      @in_child = false
      @has_block = false
      @on_wait_period = nil
      @parent_pid = $PID
      @waitpid_blocking_sleep = 1

      @serializer = Parallel::ForkManager::Serializer.new(
        params["serialize_as"] || params["serialize_type"] || "marshal"
      )
    end

    # We care about the Ruby version for a couple of reasons:
    #
    # * The new lanmbda syntax -> (1.9 and above)
    # * Finalizers (1.8 and above)
    #
    # So we only allow Ruby 1.9.* and 2.*
    def check_ruby_version
      return if RUBY_VERSION.start_with?("1.9")
      return if RUBY_VERSION.start_with?("2.")
      fail "Unsupported Ruby version #{RUBY_VERSION}!"
    end
  end # class
end # module
