require "bundler/gem_tasks"
require "rdoc/task"

RDoc::Task.new do |rdoc|
  rdoc.main = "README.rdoc"
  rdoc.rdoc_files.include(
    "README.rdoc", "EXAMPLES.rdoc", "CHANGELOG.rdoc",
    "lib/**/*.rb"
  )
end

task default: "test"

task :test do
  $LOAD_PATH.unshift "lib", "test"
  Dir.glob("./test/test_*/**/*.rb") { |f| require f }
end
