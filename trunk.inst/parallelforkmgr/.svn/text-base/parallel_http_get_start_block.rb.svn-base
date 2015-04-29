#!/usr/bin/env ruby

#require 'rubygems'
require 'net/http'
#require 'forkmanager'
require 'lib/parallel/forkmanager.rb'

my_urls = [
    'http://www.cnn.com/index.html',
    'http://oreilly.com/index.html',
    'http://www.cakewalk.com/index.html',
    'http://www.asdfsemicolonl.kj/index.htm'
]
my_timeout = 5 # seconds

max_proc = 20

pfm = Parallel::ForkManager.new(max_proc)

pfm.run_on_finish {
    |pid,exit_code,ident|
    print "** PID (#{pid}) for #{ident} exited with code #{exit_code}!\n"
}

my_urls.each {
    |my_url|

    begin
        pfm.start(my_url, 1, 2, 3) {
            |*i|
            puts i.join(', ')

            url = URI.parse(my_url)

            begin
                http = Net::HTTP.new(url.host, url.port)
                http.open_timeout = http.read_timeout = my_timeout
                res = http.get(url.path)
                status = res.code
                if status.to_i == 200
                    exit 0
                else
                    exit 255
                end
                rescue Timeout::Error
                    print "*** #{my_url} timed out!\n"
                    exit 255
                end # begin
        } # end pfm.start { ... }
    rescue Exception => e
        print "Error encountered: ", e, "\n"
        exit 255
    end
} # end each

pfm.wait_all_children()
