#!/usr/bin/env ruby

require 'net/http'
require 'lib/parallel/forkmanager'

save_dir = '/tmp'

my_urls = [
    'http://www.cnn.com/index.html',
    'http://www.oreilly.com/index.html',
    'http://www.cakewalk.com/index.html',
    'http://www.asdfsemicolonl.kj/index.htm'
]

max_proc = 20
pfm = Parallel::ForkManager.new(max_proc)

pfm.run_on_finish(
    lambda {
        |pid,exit_code,ident|
        print "** PID (#{pid}) for #{ident} exited with code #{exit_code}!\n"
    }
)

for my_url in my_urls
    pfm.start(my_url) and next

    url = URI.parse(my_url)

    begin
        req = Net::HTTP::Get.new(url.path)
        res = Net::HTTP.start(url.host, url.port) {|http|
            http.request(req)
        }
    rescue
        pfm.finish(255)
    end

    status = res.code
    out_file = save_dir + '/' + url.host + '.txt';

    if status.to_i == 200
        f = File.open(out_file, 'w')
        f.print res.body
        f.close()
        pfm.finish(0)
    else
        pfm.finish(255)
    end
end

pfm.wait_all_children()

