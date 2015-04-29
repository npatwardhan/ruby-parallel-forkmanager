#!/usr/bin/env ruby

require 'rubygems'
require 'net/http'
require 'forkmanager'

my_urls = [
    'http://www.cnn.com/index.html',
    'http://www.oreilly.com/index.html',
    'http://www.cakewalk.com/index.html',
    'http://www.asdfsemicolonl.kj/index.htm'
]

max_proc = 20
my_timeout = 5 # seconds

pfm = Parallel::ForkManager.new(max_proc)

pfm.run_on_finish(
    lambda {
        |pid,exit_code,ident|
        print "** PID (#{pid}) for #{ident} exited with code #{exit_code}!\n"
    }
)

my_urls.each {
    |my_url|

    begin
        pfm.start(my_url) and next
        url = URI.parse(my_url)
        http = Net::HTTP.new(url.host, url.port)
        http.open_timeout = http.read_timeout = my_timeout
        res = http.get(url.path)
        status = res.code
    rescue
        print "Connection to my_url had an error!\n"
        pfm.finish(255)
    end

    if status.to_i == 200
        pfm.finish(0)
    else
        pfm.finish(255)
    end
}

pfm.wait_all_children()
