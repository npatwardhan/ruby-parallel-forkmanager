#!/usr/bin/env ruby

require 'rubygems'
require 'net/http'
require 'forkmanager'

base_pfm_version = "1.2.0"

if Parallel::ForkManager::VERSION < base_pfm_version
    print "This script will only run under Parallel::ForkManager #{base_pfm_version} or newer!\n"
    print "Please update your version of Parallel::ForkManager and try again!\n"
    exit 1
end

my_urls = [
    'http://www.fakesite.us/',
    'http://www.cnn.com/',
    'http://oreilly.com/',
    'http://www.cakewalk.com/',
    'http://www.asdfsemicolonl.kj/index.htm'
]

max_proc = 20
my_timeout = 5 # seconds

pfm = Parallel::ForkManager.new(max_proc)

pfm.run_on_finish {
        |pid,exit_code,ident|
        print "** PID (#{pid}) for #{ident} exited with code #{exit_code}!\n"
}

my_urls.each {
    |my_url|

    begin
        pfm.start(my_url) and next
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
    rescue Exception => e
        print "Connection error: #{e.message}!\n"
        pfm.finish(255)
    end
}

pfm.wait_all_children

print "\n"
