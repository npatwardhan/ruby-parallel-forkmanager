# Parallel::ForkManager - A simple parallel processing fork manager.

[![Build Status](https://travis-ci.org/mikestok/ruby-parallel-forkmanager.svg?branch#master)](https://travis-ci.org/mikestok/ruby-parallel-forkmanager)

## Overview

Parallel::ForkManager is used for operations that you would like to do
in parallel.  Typical use is a downloader which could be retrieving
hundreds and/or thousands of files.

Parallel::ForkManager, as its name suggests, uses `fork` to handle parallel
processing instead of threads.  If you've used `fork` before, you're aware
that you need to be responsible for managing (i.e. cleaning up) the
processes that were created as a result of the `fork`.

Parallel::ForkManager handles this for you such that you `start` and
`finish` without having to worry about child processes along
the way.  Further, Parallel::ForkManager provides useful callbacks
that you can use when a child starts and/or finishes, or while you're
waiting for a child to complete.

The code for a downloader that uses Net::HTTP would look like this:

    require "rubygems"
    require "net/http"
    require "forkmanager"
    
    my_urls = %w(url1 url2 urlN)
    
    max_proc = 30
    my_timeout = 5
    
    pm = Parallel::ForkManager.new(max_proc)
    
    my_urls.each do |my_url|
      pm.start(my_url) && next # blocks until new fork slot is available
      # doing stuff here with my_url will be in a child
      url = URI.parse(my_url)
    
      begin
        http = Net::HTTP.new(url.host, url.port)
        http.open_timeout = http.read_timeout = my_timeout
        res = http.get(url.path)
    
        status = res.code
        if status.to_i != 200
          print "Cannot get #{url.path} from #{url.host}!\n"
          pm.finish(255)
        else
          pm.finish(0)
        end
    rescue Timeout::Error, Errno::ECONNREFUSED #> e
      print "*** ERROR: #{my_url}: #{e.message}!\n"
      pm.finish(255)
      end
    end
    
    pm.wait_all_children

First you need to instantiate the ForkManager with the `new` constructor.
You must specify the maximum number of processes to be created. If you
specify 0, then *no* `fork` will be done; this is good for debugging purposes.

Next, use `pm.start` to do the `fork`. `pm.start` returns `nil` in the child
process, and child pid in the parent process.  The `&& next` skips the internal
loop in the parent process.  *Note:* `pm.start` dies if the `fork` fails.

`pm.finish` terminates the child process (assuming a fork was done in the
`start`).

*Note:* You cannot use `pm.start` if you are already in the child process.
If you want to manage another set of subprocesses in the child process,
you must instantiate another Parallel::ForkManager object!

## Bugs and Limitations

Parallel::ForkManager is a Ruby port of Perl Parallel::ForkManager
1.14.  It was originally ported from Perl Parallel::ForkManager 0.7.5
but was recently updated to integrate features implemented in Perl
Parallel::ForkManager versions 0.7.6 - 1.14.  Bug reports and feature
requests are always welcome.

Do not use Parallel::ForkManager in an environment where other child
processes can affect the run of the main program, so using this module
is not recommended in an environment where `fork` / `wait` is already used.

If you want to use more than one copy of the Parallel::ForkManager then
you have to make sure that all children processes are terminated - before you
use the second object in the main program.

You are free to use a new copy of Parallel::ForkManager in the child
processes, although I don't think it makes sense.

## Copyright and License

### Author

Nathan Patwardhan <noopy.org@gmail.com>

### Copyright

Copyright (c) 2008 - 2015 Nathan Patwardhan

### License

Distributes under the same terms as Ruby

## Credits

### Documentation

Nathan Patwardhan <noopy.org@gmail.com>, based on Perl
Parallel::ForkManager documentation by Noah Robin
<sitz@onastick.net> and dLux <dlux@dlux.hu>.

### Credits (Perl):

- dLux <dlux@dlux.hu> (author, original Perl module)
- Gábor Szabó <szabgab@cpan.org>  (co-maintainer)
- Michael Gang (bug report)
- Noah Robin <sitz@onastick.net> (documentation tweaks)
- Chuck Hirstius <chirstius@megapathdsl.net>
  (callback exit status, original Perl example)
- Grant Hopwood <hopwoodg@valero.com> (win32 port)
- Mark Southern <mark_southern@merck.com> (bugfix)
- Ken Clarke [www.perlprogrammer.net](http://www.perlprogrammer.net)
  (data structure retrieval)

### Credits (Ruby):

- Robert Klemme <shortcutter@googlemail.com>,
  David A. Black <dblack@rubypal.com> (general awesomeness)
- Roger Pack <rogerdpack@gmail.com> (bugfix, fork semantics in start,
  doc changes)
- Mike Stok <mike@stok.ca> (test cases, percussion, backing vocals)
