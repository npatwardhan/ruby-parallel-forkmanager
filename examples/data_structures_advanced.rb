#!/usr/bin/env ruby

require "rubygems"
require "parallel/forkmanager"

max_procs = 20

pm = Parallel::ForkManager.new(max_procs, "tempdir" => "/tmp")

# data structure retrieval and handling
retrieved_responses = {} # for collecting responses

# data structure retrieval and handlin
pm.run_on_finish do |_pid, _exit_code, ident, _exit_signal, _core_dump, data|
  if data # test rather than assume child sent anything
    puts "#{ident} returned #{data.inspect}."

    retrieved_responses[ident] = data
  else
    puts "#{ident} did not send anything."
  end
end

# generate a list of instructions
instructions = [  # a unique identifier and what the child process should send
  { "name" => "ENV keys as a string", "send" => "keys" },
  { "name" => "Send Nothing" },
  { "name" => "Childs ENV", "send" => "all" },
  { "name" => "Child chooses randomly", "send" => "random" },
  { "name" => "Invalid send instructions", "send" => "Na Na Nana Na" },
  { "name" => "ENV values in an array", "send" => "values" }
]

# run the parallel processes
instructions.each do |instruction|
  # this time we are using an explicit, unique child process identifier
  pm.start(instruction["name"]) && next

  unless instruction.key?("send")
    puts "MT name #{instruction['name']}"
    pm.finish(0)
  end

  data = case instruction["send"]
         when "keys"   then ENV.keys
         when "values" then ENV.values
         when "all"    then ENV.to_h
         when "random"
           ["I'm just a string.",
            %w(I am an array),
            { "type" => "associative array",
              "synonym" => "hash",
              "cool" => "very :)" }
           ].sample
         else
           "Invalid instructions: #{instruction['send']}"
         end

  pm.finish(0, data)
end

pm.wait_all_children

# post fork processing of returned data structures
retrieved_responses.keys.sort.each do |response|
  puts "Post processing \"#{response}\"..."
end
