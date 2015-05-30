require "bundler/gem_tasks"
require "yard"

task default: "test"

task :test do
  $LOAD_PATH.unshift "lib", "test"
  Dir.glob("./test/test_*/**/*.rb") { |f| require f }
end

OTHER_DOC_FILES = %w(README.md EXAMPLES.yard CHANGELOG.md)
YARD::Rake::YardocTask.new do |t|
  # The reason for .md and .yard is that Github won't show the included
  # files if it's markdown, so this attempts to put the "useful" files in
  # markdown.
  t.files   = %w(lib/**/*.rb - README.md CHANGELOG.md EXAMPLES.yard)
  t.stats_options = ["--list-undoc"]         # optional
end
