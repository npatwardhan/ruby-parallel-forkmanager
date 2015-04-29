# Parallel::ForkManager -- A simple parallel processing fork manager.
#
#
# Copyright (c) 2008 Nathan Patwardhan
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
# - Robert Klemme <shortcutter@googlemail.com> (clarification on Ruby lambda)
# - David A. Black <dblack@rubypal.com>        (clarification on Ruby lambda)
# - Roger Pack <rogerdpack@gmail.com>          (bugfix)
#
# == Overview
#
# Parallel::ForkManager is used for operations that you would like to do in parallel
# (e.g. downloading a bunch of web content simultaneously) but would prefer to use
# fork() instead of threads.  Instead of managing child processes yourself Parallel::ForkManager
# handles the cleanup for you.  Parallel::ForkManager also provides some nifty callbacks
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
#  require 'net/http'
#  require 'Parallel/ForkManager'
#
#  save_dir = '/tmp'
#
#  my_urls = [
#      'http://www.cnn.com/index.html',
#      'http://www.oreilly.com/index.html',
#      'http://www.cakewalk.com/index.html',
#      'http://www.asdfsemicolonl.kj/index.htm'
#  ]
#
#  max_proc = 20
#  pfm = Parallel::ForkManager.new(max_proc)
#
#  pfm.run_on_finish(
#      lambda {
#          |pid,exit_code,ident|
#          print "** PID (#{pid}) for #{ident} exited with code #{exit_code}!\n"
#      }
#  )
#
#  for my_url in my_urls
#      pfm.start(my_url) and next
#
#      url = URI.parse(my_url)
#
#      begin
#          req = Net::HTTP::Get.new(url.path)
#          res = Net::HTTP.start(url.host, url.port) {|http|
#              http.request(req)
#          }
#      rescue
#          pfm.finish(255)
#      end
#
#      status = res.code
#      out_file = save_dir + '/' + url.host + '.txt';
#
#      if status.to_i == 200
#          f = File.open(out_file, 'w')
#          f.print res.body
#          f.close()
#          pfm.finish(0)
#      else
#          pfm.finish(255)
#      end
#  end
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
# == Bugs and Limitations
#
# Parallel::ForkManager is a Ruby-centric rebase of Perl Parallel::ForkManager 0.7.5.
# While much of the original code was rewritten such that ForkManager worked in the "Ruby way",
# you might find some "warts" due to inconsistencies between Ruby and the original Perl code.
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

module Parallel

class ForkManager
    VERSION = '1.0.1' # $Revision: 49 $

# Set debug to 1 for debugging messages.
    attr_accessor :debug
    attr_accessor :max_proc, :processes, :in_child, :on_wait_period
    attr_accessor :do_on_start, :do_on_finish, :do_on_wait

    def initialize(procs)
        @debug = 0
        @max_proc = procs
        @processes = {}
        @do_on_finish = {}
        @in_child = 0

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
# process.  See run_on_finish() for more information.
#
# Return: PID of child process if in parent, or 0 if in the
# child process.

    def start(identification=nil)
        if self.in_child == 1
            puts "Cannot start another process while you are in the child process"
            exit 1
        end

        while(self.processes.length() >= self.max_proc)
            self.on_wait()
            if defined? self.on_wait_period
                arg = Process::WNOHANG
            else
                arg = nil
            end
            self.wait_one_child(arg)
        end
        
        self.wait_children()

        if self.max_proc
            pid = fork()
            if ! defined? pid
                print "Cannot fork #{$!}\n"
                exit 1
            end
            
            if pid != nil
                self.processes[pid] = identification
                self.on_start(pid, identification)
            else
                if ! pid
                    self.in_child = 1
                end
            end
            return pid
        else
            self.processes[$$] = identification
            self.on_start($$, identification)
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
        if self.in_child == 1
            exit exit_code || 0
        end

        if self.max_proc == 0
            self.on_finish($$, exit_code, self.processes[$$], 0, 0)
            self.processes.delete($$)
        end
        
        return 0
    end
        
    def wait_children()
        return if self.processes.empty?
        
        kid = nil # Should our default be nil?
        loop do
            kid = self.wait_one_child(Process::WNOHANG)
            break if kid > 0 || kid < -1
        end
    end
    
    alias :wait_childs :wait_children # compatibility

#
# Probably won't want to call this directly.  Just let wait_all_children(...)
# make the call for you.
#
    def wait_one_child(parent)
        kid = nil
        while true
            # Call _NT_waitpid(...) if we're using a Windows or Java variant.
            if(RUBY_PLATFORM =~ /mswin|mingw|bccwin|wince|emx|java/)
                kid = self._NT_waitpid(-1, parent ||= 0)
            else
                kid = self._waitpid(-1, parent ||= 0)
            end
            last if kid == 0 or kid == -1 # Win32 returns negative PIDs
            redo if ! self.processes.has_key?(kid)
            id = self.processes.delete(kid)
            self.on_finish(kid, $? >> 8, id, $? & 0x7f, $? & 0x80 ? 1 : 0)
            break
        end

        kid
    end

#
# wait_all_children() will wait for all the processes which have been 
# forked. This is a blocking wait.
#
    def wait_all_children()
        while ! self.processes.empty?
            self.on_wait()
            if defined? self.on_wait_period
                arg = Process::WNOHANG
            else
                arg = nil
            end
            self.wait_one_child(arg)
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
    def run_on_finish(code, pid=0)
        begin
            self.do_on_finish[pid] = code
        rescue
            raise "couldn't run on finish!\n"
        end
    end

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
    def run_on_wait(code, period)
        self.do_on_wait = code
        self.on_wait_period = period
    end
    
    def on_wait()
        begin
            if self.do_on_wait.class().name == 'Proc'
                self.do_on_wait.call()
                if defined? self.on_wait_period
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
    def run_on_start(code)
        begin
            self.do_on_start = code
        rescue
            raise "run on start failed!\n"
        end
    end

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
# _waitpid(...) should not be called directly as it is called automatically by
# wait_one_child(...).
#
    def _waitpid(pid, flags)
        return Process.waitpid(pid, flags)
    end

#
# _NT_waitpid(...) is the Windows variant of _waitpid(...) and will be called
# automatically by wait_one_child(...) depending on the value of RUBY_PLATFORM.
# You should not call _NT_waitpid(...) directly.
#
    def _NT_waitpid(pid, par)
        if par == Process::WNOHANG
            pids = self.processes.keys()
            if pids.length() == 0
                return -1
            end
            
            kid = 0
            for my_pid in pids
                kid = Process.waitpid(my_pid, par)
                if kid != 0
                    return kid
                end
            return kid
            end
        else
            return Process.waitpid(pid, par)    
        end
    end
end
    
end
