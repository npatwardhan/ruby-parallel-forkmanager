#!/usr/bin/env ruby

require "rubygems"
require "parallel/forkmanager"

max_procs = 2
persons = %w(Fred Wilma Ernie Bert Lucy Ethel Curly Moe Larry)

pm = Parallel::ForkManager.new(max_procs, "tempdir" => "/tmp")

# data structure retrieval and handling
pm.run_on_finish do |pid, _exit_code, _ident, _exit_signal, _core_dump, data|
  if data # children are not forced to send anything
    puts data
  else  # problems occuring during storage or retrieval will throw a warning
    puts "No message received from child process #{pid}!"
  end
end

# prep random statement components
foods = [
  "chocolate", "ice cream", "peanut butter", "pickles", "pizza", "bacon",
  "pancakes", "spaghetti", "cookies"
]
opinions = [
  "loves", "can't stand", "always wants more", "will walk 100 miles for",
  "only eats", "would starve rather than eat"
]

# run the parallel processes
persons.each do |person|
  pm.start && next

  # generate a random statement about food preferences
  statement = "#{person} #{opinions.sample} #{foods.sample}"

  if rand(5) > 0
    pm.finish(0, statement)
  else
    pm.finish(0)
  end
end

pm.wait_all_children
