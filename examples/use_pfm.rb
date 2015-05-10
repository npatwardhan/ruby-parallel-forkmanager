#!/usr/bin/env ruby

require "rubygems"
# require 'forkmanager'
require "lib/parallel/forkmanager"

max_procs = 5
pfm = Parallel::ForkManager.new(max_procs)

items = (1..10).to_a

pfm.run_on_start do |pid, ident|
  print "run on start ::: #{ident} (#{pid})\n"
end

pfm.run_on_finish do |pid, exit_code, ident|
  print "run on finish ::: ** PID: #{pid} EXIT: #{exit_code} IDENT: #{ident}\n"
end

period = 1.0
pfm.run_on_wait(period) do
  print "** Have to wait for one child ...\n"
end

items.each do |item|
  my_item = "nate-" + item.to_s
  pid = pfm.start(my_item) and next
  pfm.finish(23)
end

pfm.wait_all_children
