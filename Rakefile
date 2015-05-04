require 'rubygems'
require 'rake/gempackagetask'

# $Id: Rakefile 52 2011-03-04 21:26:56Z nvp $
# $Revision: 52 $

spec = Gem::Specification.new do |s|
    s.platform  =   Gem::Platform::RUBY
    s.name      =   "parallel-forkmanager"
    s.version   =   "2.0.0"
    s.author    =   "Nathan Patwardhan"
    s.rubyforge_project = "parallelforkmgr"
    s.homepage  =   "http://rubyforge.org/projects/parallelforkmgr/"
    s.email     =   "noopy.org @nospam@ gmail.com"
    s.summary   =   "A simple parallel processing fork manager."
    s.files     =   FileList['lib/parallel/*.rb', 'use_pfm.rb', 'parallel_http_get.rb'].to_a
    s.require_path  =   "lib/parallel"
    s.has_rdoc  =   true
end

Rake::GemPackageTask.new(spec) do |pkg|
    pkg.need_tar = true
end

task :default => "pkg/#{spec.name}-#{spec.version}.gem" do
    puts "generated latest version"
end
