require "rubygems"
require "rubygems/package_task"

spec = Gem::Specification.new do |s|
  s.platform  =   Gem::Platform::RUBY
  s.name      =   "parallel-forkmanager"
  s.version   =   "2.0.3"
  s.author    =   "Nathan Patwardhan"
  s.rubyforge_project = "parallelforkmgr"
  s.homepage  =   "https://github.com/npatwardhan/ruby-parallel-forkmanager/"
  s.email     =   "noopy.org<at>gmail.com"
  s.description = <<-ETX
A simple parallel processing fork manager, based on the Perl module.
  ETX
  s.license   =   "Ruby"
  s.summary   =   "A simple parallel processing fork manager."

  s.files     =   FileList["lib/parallel/*.rb", "examples/*.rb"].to_a
  s.require_path  =   "lib/parallel"
  s.has_rdoc  =   true
end

Gem::PackageTask.new(spec) do |pkg|
  pkg.need_tar = true
end

task default: "gem"

task :test do
  $LOAD_PATH.unshift "lib", "test"
  Dir.glob("./test/test_*/**/*.rb") { |f| require f }
end
