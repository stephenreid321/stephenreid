require 'rake/testtask'

desc 'Run the tests (test/**/*_test.rb) and the Cloudflare Worker\'s (cloudflare/*.test.js, needs Node)'
task test: %w[test:ruby test:worker]

namespace :test do
  # Not test/lint_test.rb, which script/lint runs, as CI's lint job does: rake test:lint runs it alone
  Rake::TestTask.new(:ruby) do |t|
    t.description = 'Run the Ruby tests, in one process, but for test/lint_test.rb'
    t.libs << 'test'
    t.test_files = FileList['test/**/*_test.rb'].exclude('test/lint_test.rb')
    t.warning = false
  end

  desc "Run the Cloudflare Worker's tests, with Node's test runner"
  task :worker do
    sh 'node', '--test', *Dir['cloudflare/*.test.js']
  end

  # Each file by its path in test/, as rake test:iconomi/strategy
  Dir['test/**/*_test.rb'].each do |file|
    Rake::TestTask.new(file.delete_prefix('test/').delete_suffix('_test.rb')) do |t|
      t.description = "Run #{file}"
      t.libs << 'test'
      t.test_files = [file]
      t.warning = false
    end
  end
end
