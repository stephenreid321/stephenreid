require 'test_config'

# lib/fetched.rb: what's fetched from other sites, as JSON files in data/fetched
class FetchedTest < ActiveSupport::TestCase
  # Runs the block with data/fetched in a temporary folder, empty
  def in_fetched_dir(&)
    Dir.mktmpdir do |dir|
      fetched = File.join(dir, 'fetched')
      Fetched.stub(:path, ->(name) { File.join(fetched, "#{name}.json") }, &)
    end
  end

  test "writes each as JSON, makes the folder if there's none, and reads it back" do
    in_fetched_dir do
      refute Fetched.exist?(:places)
      Fetched.write(:places, [{ name: 'Communities', places: [] }])

      assert Fetched.exist?(:places)
      assert_equal [{ 'name' => 'Communities', 'places' => [] }], Fetched.read(:places)
      assert_equal '[{"name":"Communities","places":[]}]', File.read(Fetched.path(:places))
    end
  end

  test 'reads one not fetched yet as the default: so the site builds without it, showing nothing' do
    in_fetched_dir do
      assert_equal [], Fetched.read(:places)
      assert_equal({}, Fetched.read(:courses, {}))
    end
  end

  test 'keeps them in data/fetched' do
    assert_equal File.join(ROOT, 'data/fetched/iconomi.json'), Fetched.path(:iconomi)
  end
end
