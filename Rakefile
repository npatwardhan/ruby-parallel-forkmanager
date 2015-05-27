require "bundler/gem_tasks"

task default: "test"

task :test do
  $LOAD_PATH.unshift "lib", "test"
  Dir.glob("./test/test_*/**/*.rb") { |f| require f }
end
