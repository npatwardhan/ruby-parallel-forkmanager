#!/usr/bin/env ruby

# require 'rubygems'
require "net/http"
# require 'forkmanager'
require "lib/parallel/forkmanager.rb"

min_version = "1.2.0"

if Parallel::ForkManager::VERSION < min_version
  warn <<-ETX
This script will only run under Parallel::ForkManager #{min_version} or newer!
Please update your version of Parallel::ForkManager and try again!
  ETX
  exit 1
end

my_urls = [
  "http://www.fakesite.us/",
  "http://www.cnn.com/",
  "http://oreilly.com/",
  "http://www.cakewalk.com/",
  "http://www.asdfsemicolonl.kj/index.htm"
]

max_proc = 20
my_timeout = 5 # seconds

pfm = Parallel::ForkManager.new(max_proc)

pfm.run_on_finish do |pid, exit_code, ident|
  print "** PID (#{pid}) for #{ident} exited with code #{exit_code}!\n"
end

my_urls.each do |my_url|
  begin
    pfm.start(my_url) && next
    url = URI.parse(my_url)

    begin
      http = Net::HTTP.new(url.host, url.port)
      http.open_timeout = http.read_timeout = my_timeout
      res = http.get(url.path)
      status = res.code

      # You may want to check some other code than 200 here!
      if status.to_i == 200
        pfm.finish(0)
      else
        pfm.finish(255)
      end
  rescue Timeout::Error => e
    print "*** #{my_url}: #{e.message}!\n"
    pfm.finish(255)
    end # begin
rescue StandardError => e
  print "Connection error: #{e.message}!\n"
  pfm.finish(255)
  end
end

pfm.wait_all_children

print "\n"
