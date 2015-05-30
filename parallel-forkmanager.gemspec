require "pathname"
lib = (Pathname(__FILE__).dirname + "lib").to_s
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "parallel/forkmanager/version"

Gem::Specification.new do |s|
  s.platform  =   Gem::Platform::RUBY
  s.name      =   "parallel-forkmanager"
  s.version   =   Parallel::ForkManager::VERSION
  s.author    =   "Nathan Patwardhan"
  s.homepage  =   "https://github.com/npatwardhan/ruby-parallel-forkmanager/"
  s.email     =   "noopy.org<at>gmail.com"
  s.description = <<-ETX
A simple parallel processing fork manager, based on the Perl module.
  ETX
  s.license   =   "Ruby"
  s.summary   =   "A simple parallel processing fork manager."

  s.files         = `git ls-files -z`.split("\x0")
    .reject { |f| f.match(%r{^(test|spec|features)/}) }
  s.bindir        = "bin"
  s.executables   = s.files.grep(%r{^exe/}) { |f| File.basename(f) }
  s.require_paths = ["lib"]

  # recommended versions commented out because we are testing against some
  # older rubies...
  s.add_development_dependency "bundler"  # , "~> 1.9"
  s.add_development_dependency "rake"     # , "~> 10.0"
  s.add_development_dependency "minitest"
  s.add_development_dependency "pry"
  s.add_development_dependency "yard"
end
