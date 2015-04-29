#!/usr/bin/env ruby

require "lib/parallel/forkmanager"

num_procs = 20
pfm = Parallel::ForkManager.new(num_procs)

items = 1..10

pfm.run_on_start(
    lambda {
        |pid,ident|
        print "run on start ::: #{ident} (#{pid})\n"
    }
)

pfm.run_on_finish(
    lambda {
        |pid,exit_code,ident|
        print "  on_finish: ** PID: #{pid} EXIT: #{exit_code} IDENT: #{ident}\n"
    }
)

timeout = 0.5
pfm.run_on_wait(
    lambda {
        print "** Have to wait for one child ...\n"
    },
    timeout
)

for item in items
    my_item = 'nate-' + item.to_s
    pid = pfm.start(my_item) and next

    pfm.finish()
end

pfm.wait_all_children()

