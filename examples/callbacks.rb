#!/usr/bin/env ruby

require "rubygems"
require "parallel/forkmanager"

max_procs = 5
names = %w(Fred Jim Lily Steve Jessica Bob Dave Christine Rico Sara)

pm = Parallel::ForkManager.new(max_procs)

# Setup a callback for when a child finishes up so we can get its exit code
pm.run_on_finish do |pid, exit_code, ident|
  puts "** #{ident} just got out of the pool with PID #{pid} and exit code: #{exit_code}"
end

pm.run_on_start do |pid, ident|
  puts "** #{ident} started, pid: #{pid}"
end

pm.run_on_wait(0.5) do
  puts "** Have to wait for one children ..."
end

names.each_index do |child|
  pm.start(names[child]) && next

  # This code is the child process
  puts "This is #{names[child]}, Child number #{child}"
  sleep(2 * child)
  puts "#{names[child]}, Child #{child} is about to get out..."
  sleep 1
  pm.finish(child) # pass an exit code to finish
end

puts "Waiting for Children..."
pm.wait_all_children
puts "Everybody is out of the pool!"
