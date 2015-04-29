# Parallel::ForkManager -- A simple parallel processing fork manager.
#
#
# Copyright (c) 2008 - 2010 Nathan Patwardhan
#
# Author: Nathan Patwardhan <noopy.org@gmail.com>
#
# Documentation: Nathan Patwardhan <noopy.org@gmail.com>, based on Perl Parallel::ForkManager documentation by Noah Robin <sitz@onastick.net> and dlux <dlux@kapu.hu>.
#
# Credits (for original Perl implementation):
# - Chuck Hirstius <chirstius@megapathdsl.net> (callback exit status, original Perl example)
# - Grant Hopwood <hopwoodg@valero.com> (win32 port)
# - Mark Southern <mark_southern@merck.com> (bugfix)
#
# Credits (Ruby port):
# - Robert Klemme <shortcutter@googlemail.com>, David A. Black <dblack@rubypal.com>        (general awesomeness)
# - Roger Pack <rogerdpack@gmail.com>          (bugfix, fork semantics in start, doc changes)
# - Mike Stok <mike@stok.ca>          (test cases, percussion, backing vocals)
#
# == Overview
#
# Parallel::ForkManager is used for operations that you would like to do in parallel
# (e.g. downloading a bunch of web content simultaneously) but would prefer to use
# fork() instead of threads.  Instead of managing child processes yourself Parallel::ForkManager
# handles the cleanup for you.  Parallel::ForkManager also provides some useful callbacks
# you can use at start and finish, or while you're waiting for child processes to complete.
#
# == Introduction
#
# If you've used fork() before, you're well aware that you need to be responsible
# for managing (i.e. cleaning up) the processes that were created as a result.
# Parallel::ForkManager handles this for you such that you start() and finish()
# a process without having to worry about child processes along the way.
#
# For instance you can use the following code to grab a list of webpages in
# parallel using Net::HTTP -- and store the output in files.
#
# == Example
#
#  #!/usr/bin/env ruby
#
#  require 'rubygems'
#  require 'net/http'
#  require 'forkmanager'
#  
#  my_urls = [
#      'url1',
#      'url2',
#      'urlN'
#  ]
#  
#  max_proc = 20
#  my_timeout = 5 # seconds
#  
#  pfm = Parallel::ForkManager.new(max_proc)
#  
#  my_urls.each {
#      |my_url|
#  
#      begin
#          pfm.start(my_url) and next # blocks until new fork slot is available
#
#          # doing stuff here with my_url will be in a child
#          url = URI.parse(my_url)
#          http = Net::HTTP.new(url.host, url.port)
#          http.open_timeout = http.read_timeout = my_timeout
#          res = http.get(url.path)
#          status = res.code
#      rescue
#          print "Connection to #{my_url} had an error!\n"
#          pfm.finish(255)
#      end
#  
#      if status.to_i == 200
#          pfm.finish(0) # exit the forked process with this status
#      else
#          pfm.finish(255) # exit the forked process with this status
#      end
#  }
#  
#  pfm.wait_all_children()
#  
# First you need to instantiate the ForkManager with the "new" constructor. 
# You must specify the maximum number of processes to be created. If you 
# specify 0, then NO fork will be done; this is good for debugging purposes.
#
# Next, use pfm.start() to do the fork. pfm returns 0 for the child process, 
# and child pid for the parent process.  The "and next" skips the internal
# loop in the parent process.
#
# - pm.start() dies if the fork fails.
#
# - pfm.finish() terminates the child process (assuming a fork was done in the "start").
#
# - You cannot use pfm.start() if you are already in the child process. 
# If you want to manage another set of subprocesses in the child process, 
# you must instantiate another Parallel::ForkManager object!
#
# == Revision History
#
# - 1.2.0, 2010-02-01: Resolves bug [#27748] finish throws an error when used with start(ident).  Adds block support to run_on_start(), run_on_wait(), run_on_finish().
# - 1.1.1, 2010-01-05: Resolves bug with Errno::ECHILD.
# - 1.1.0, 2010-01-01: Resolves bug [#27661] forkmanager doesn't fork!.  Adds block support to start() w/doc changes for same.
# - 1.0.1, 2009-10-24: Resolves bug [#27328] dies with max procs 1.
# - 1.0.0, 2008-11-03: Initial release.
#
# == Bugs and Limitations
#
# Parallel::ForkManager is a Ruby port of Perl Parallel::ForkManager 0.7.5.
# While much of the original code was rewritten such that ForkManager worked in the "Ruby way",
# you might find some "warts" due to inconsistencies between Ruby and the original Perl code.  Bug reports and feature requests are always welcome.
#
# Do not use Parallel::ForkManager in an environment where other child
# processes can affect the run of the main program, so using this module
# is not recommended in an environment where fork() / wait() is already used.
#
# If you want to use more than one copy of the Parallel::ForkManager then
# you have to make sure that all children processes are terminated -- before you
# use the second object in the main program.
#
# You are free to use a new copy of Parallel::ForkManager in the child
# processes, although I don't think it makes sense.
#
include Process

module Parallel

class ForkManager
    VERSION = '1.2.0' # $Revision: 51 $

# Set debug to 1 for debugging messages.
    attr_accessor :debug
    attr_accessor :max_proc, :processes, :in_child, :has_block, :on_wait_period
    attr_accessor :do_on_start, :do_on_finish, :do_on_wait

    def initialize(procs)
        @debug = 0
        @max_proc = procs
        @processes = {}
        @do_on_finish = {}
        @in_child = false
        @has_block = false
        @on_wait_period = nil

        if self.debug == 1
            print "in initialize #{max_proc}!\n"
        end
    end

#
# start("string") -- "string" identification is optional.
#
# start("string") "puts the fork in Parallel::ForkManager" -- as start() does
# the fork().
#
# start("string") takes an optional "string" argument to
# use as a process identifier.  It is used by 
# the "run_on_finish" callback for identifying the finished
# process.  See run_on_finish() for more information.  For example:
#
#   my_ident = "webwacker-1.0"
#   pfm.start(my_ident)
#
# start("string") { block } takes an optional block parameter
# that tells the ForkManager to follow Ruby fork() semantics for blocks.
# For example:
#
#   my_ident = "webwacker-1.0"
#   pfm.start(my_ident) {
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
#   pfm.start(my_ident, 1, 2, 3) {
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
# parameter, the code in your block *must* explicitly exit non-zero if you are
# using callbacks with the ForkManager (e.g. run_on_finish).</em>  This is
# because fork(), when run with a block parameter, terminates the subprocess
# with a status of 0 by default.  If your block fails to exit non-zero,
# *all* of your exit_code(s) will be zero regardless of any value you might
# have passed to finish(...).
#
# To accommodate this behavior of fork and blocks, you can do
# something like the following:
#
#   my_urls = [ ... some list of urls here ... ]
#   my_ident = "webwacker-1.0"
#
#   my_urls.each {
#       |my_url|
#       pfm.start(my_ident) {
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
# Return: PID of child process if in parent, or 0 if in the
# child process.

    def start(identification=nil, *args, &run_block)
        if self.in_child
            raise "Cannot start another process while you are in the child process" \
        end

        while(self.processes.length() >= self.max_proc)
            on_wait()
            arg = (defined? self.on_wait_period and !self.on_wait_period.nil?) ? Process::WNOHANG : nil
            self.wait_one_child(arg)
        end

        self.wait_children()

        if self.max_proc
            if(block_given?)
                raise "start(...) wrong number of args\n" if run_block.arity >= 0 && args.size != run_block.arity
                self.has_block = true
                pid = (! args.empty?) ? fork { run_block.call(*args); } : fork { run_block.call(); }
            else
                if !args.empty?
                    raise "start(...) args given but block is empty!\n"
                end

                pid = fork()
            end
            raise "Cannot fork #{$!}\n" if ! defined? pid

            if pid.nil?
                self.in_child = true
            else
                self.processes[pid] = identification
                on_start(pid, identification)
            end

            return pid
        else
            self.processes[$$] = identification
            on_start($$, identification)

            return 0
        end        
    end

#
# finish(exit_code) -- exit_code is optional
#
# finish() loses the child process by exiting and accepts an optional exit code.
# Default exit code is 0 and can be retrieved in the parent via callback.
# If you're running the program in debug mode (max_proc == 0), this method
# doesn't do anything.
#
    def finish(exit_code = 0)
        if self.has_block
            raise "Do not use finish(...) when using blocks.  Use an explicit exit in your block instead!\n"
        end

        if self.in_child
            exit_code ||= 0
            Kernel.exit!(exit_code)
        end

        if self.max_proc == 0
            on_finish($$, exit_code, self.processes[$$], 0, 0)
            self.processes.delete($$)
        end
        return 0
    end
        
    def wait_children()
        return if self.processes.keys().empty?

        kid = nil
        begin
            begin
                kid = self.wait_one_child(Process::WNOHANG)
            end while kid > 0 || kid < -1
        rescue Errno::ECHILD
            return
        end
    end
    
    alias :wait_childs :wait_children # compatibility

#
# Probably won't want to call this directly.  Just let wait_all_children(...)
# make the call for you.
#
    def wait_one_child(par)
        params = par || 0

        kid = nil
        while true
            # Call _NT_waitpid(...) if we're using a Windows or Java variant.
            if(RUBY_PLATFORM =~ /mswin|mingw|bccwin|wince|emx|java/)
                kid = _NT_waitpid(-1, params)
            else
                kid = _waitpid(-1, params)
            end

            break if kid == nil or kid == -1 # Win32 returns negative PIDs

            redo if ! self.processes.has_key?(kid)
            id = self.processes.delete(kid)
            on_finish(kid, $? >> 8, id, $? & 0x7f, $? & 0x80 ? 1 : 0)
            break
        end

        kid ||= 0
        kid
    end

#
# wait_all_children() will wait for all the processes which have been 
# forked. This is a blocking wait.
#
    def wait_all_children()
        begin
            while ! self.processes.keys().empty?
                on_wait()
                arg = (defined? self.on_wait_period and !self.on_wait_period.nil?) ? Process::WNOHANG : nil
                self.wait_one_child(arg)
            end
        rescue Errno::ECHILD
            return
        end
    end
    
    alias :wait_all_childs :wait_all_children # compatibility

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
#
# Example:
#
#   pfm.run_on_finish(
#       lambda {
#           |pid,exit_code,ident|
#           print "** PID (#{pid}) for #{ident} exited with code #{exit_code}!\n"
#       }
#   )
#
# <em>NOTE NOTE NOTE: Passing Proc to run_on_finish will be deprecated in
# Parallel::ForkManager 1.3!  Please use the form shown below now!</em>
#
# As of Parallel::ForkManager 1.2.0 run_on_finish supports a block argument
# instead of needing to pass in a Proc explicitly.
#
# Example:
#
#   pfm.run_on_finish {
#           |pid,exit_code,ident|
#           print "** PID (#{pid}) for #{ident} exited with code #{exit_code}!\n"
#   }
#
    def run_on_finish(code=nil, pid=0, &my_block)
        begin
            if !code.nil? && !my_block.nil?
                raise "run_on_finish: code and block are mutually exclusive options!"
            end

            if !code.nil?
                self.do_on_finish[pid] = code
            elsif !my_block.nil?
                self.do_on_finish[pid] = my_block
            end
        rescue TypeError => e
            raise e.message
        end
    end

#
# on_finish is a private method and should not be called directly.
#
    def on_finish(*params)
        pid = params[0]
        code = self.do_on_finish[pid] || self.do_on_finish[0] or return 0
        begin
            my_argc = code.arity - 1
            if my_argc > 0
                my_params = params[0 .. my_argc]
            else
                my_params = [params[0]]
            end
            params = my_params
            code.call(*params)
        rescue
            raise "on finish failed!\n"
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
#   timeout = 0.5
#   pfm.run_on_wait(
#       lambda {
#           print "** Have to wait for one child ...\n"
#       },
#       timeout
#   )
#
# <em>NOTE NOTE NOTE: Passing Proc to run_on_wait will be deprecated in
# Parallel::ForkManager 1.3!  Please use the form shown below now!</em>
#
# As of Parallel::ForkManager 1.2.0 run_on_wait supports a block argument
# instead of needing to pass in a Proc explicitly.
#
# Example:
#   timeout = 0.5
#   pfm.run_on_wait(timeout) {
#           print "** Have to wait for one child ...\n"
#   }
#
# NOTE: The previous form of run_on_wait will be deprecated in
# Parallel::ForkManager 1.3.0!
#

    def run_on_wait(*params, &block)
        begin
            raise "period is required by run_on_wait\n" if !params.length

            if params.length == 1
                period = params[0]
                raise "period must be of type float!\n" if period.class.to_s.downcase() != "float"
            elsif params.length == 2
                code, period = params
                raise "run_on_wait: Missing or invalid code block!\n" if code.class.to_s.downcase() != "proc"
            else
                raise "run_on_wait: Invalid argument count!\n"
            end

            self.on_wait_period = period
            raise "Wait period must be greater than 0.0!\n" if period == 0

            if ! code.nil? && ! block.nil?
                raise "run_on_wait: code and block are mutually exclusive arguments!"
            end

            if ! code.nil?
                self.do_on_wait = code
            elsif !block.nil?
                self.do_on_wait = block
            end
        rescue TypeError
            raise "run on wait failed!\n"
        end
    end

#
# on_wait is a private method as it should not be called directly.
#
    def on_wait()
        begin
            if self.do_on_wait.class().name == 'Proc'
                self.do_on_wait.call()
                if defined? self.on_wait_period and !self.on_wait_period.nil?
                    #
                    # Unfortunately Ruby 1.8 has no concept of 'sigaction',
                    # so we're unable to check if a signal handler has
                    # already been installed for a given signal.  In this
                    # case it's no matter, since we define handler, but yikes.
                    #
                    Signal.trap("CHLD") do
                        lambda{}.call()
                    end
                    IO.select(nil, nil, nil, self.on_wait_period)
                end
            end
        end
    end

#
# You can define a subroutine which is called when a child is started. It is
# called after a successful startup of a child in the parent process.
#
# The parameters of code are as follows:
# - pid of the process which has been started
# - identification of the process (if provided in the "start" method)
#
# Example:
#
#   pfm.run_on_start(
#       lambda {
#           |pid,ident|
#           print "run on start ::: #{ident} (#{pid})\n"
#       }
#   )
#
# <em>NOTE NOTE NOTE: Passing Proc to run_on_start will be deprecated in
# Parallel::ForkManager 1.3!  Please use the form shown below now!</em>
#
# As of Parallel::ForkManager 1.2.0 run_on_start supports a block argument
# instead of needing to pass in a Proc explicitly.
#
# Example:
#
#   pfm.run_on_start() {
#           |pid,ident|
#           print "run on start ::: #{ident} (#{pid})\n"
#       }
#
# Note that code and block are mutually exclusive arguments.  If you try
# to use pass both a Proc and a block to run_on_start it will raise an error.
#
    def run_on_start(code=nil, &block)
        begin
            if ! code.nil? && ! block.nil?
                raise "run_on_start: code and block are mutually exclusive arguments!"
            end

            if ! code.nil?
                self.do_on_start = code
            elsif !block.nil?
                self.do_on_start = block
            end
        rescue TypeError
            raise "run on start failed!\n"
        end
    end

#
# on_start() is a private method as it should not be called directly.
#
    def on_start(*params)
        begin
            if self.do_on_start.class().name == 'Proc'
                my_argc = self.do_on_start.arity - 1
                if my_argc > 0
                    my_params = params[0 .. my_argc]    
                else
                    my_params = params[0]
                end
                params = my_params
                self.do_on_start.call(*params)
            end
        rescue
            raise "on_start failed\n"
        end       
    end

#
# set_max_procs(mp) -- mp is an integer
#
# set_max_procs() allows you to set a new maximum number of children to maintain.
#
# Return: The previous setting of max_procs.
#
    def set_max_procs(mp=nil)
        if mp == nil
            return self.max_proc
        else
            self.max_proc = mp
        end
    end

#
# _waitpid(...) is a private method as it should not be called directly.
# It is called automatically by wait_one_child(...).
#
    def _waitpid(pid, flags)
        return waitpid(pid, flags)
    end

#
# _NT_waitpid(...) is a private method as it should not be called directly.
#
# _NT_waitpid(...) implements the Windows variant of _waitpid(...) and will
# be called automatically by wait_one_child(...) depending on the value of
# RUBY_PLATFORM.
#
    def _NT_waitpid(pid, par)
        if par == Process::WNOHANG
            pids = self.processes.keys()
            if pids.length() == 0
                return -1
            end
            
            kid = 0
            for my_pid in pids
                kid = waitpid(my_pid, par)
                if kid != 0
                    return kid
                end
            return kid
            end
        else
            return waitpid(pid, par)    
        end
    end

    # private methods
    private :on_start, :on_finish, :on_wait, :_waitpid, :_NT_waitpid

end
    
end
