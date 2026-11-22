require 'test_config'

# lib/substack.rb's Substack.fetch (rake data:substack): the notes and the posts, fetched at once
class SubstackFetchTest < ActiveSupport::TestCase
  test 'fetches the notes and the posts at once, each on a thread of its own' do
    started = Queue.new
    # Each waits for the other to start, so they can only both finish if they run at the same time
    wait_for_other = lambda do |name|
      started << name
      Timeout.timeout(2) { sleep 0.01 until started.size == 2 }
      Thread.current
    end
    threads = []
    SubstackNote.stub(:import, -> { threads << wait_for_other.call(:notes) }) do
      SubstackPost.stub(:import, -> { threads << wait_for_other.call(:posts) }) { Substack.fetch }
    end

    assert_equal 2, threads.uniq.size
    refute_includes threads, Thread.current
  end

  test 'fails if either fails' do
    SubstackNote.stub(:import, -> { raise 'Substack said 403' }) do
      SubstackPost.stub(:import, -> {}) { assert_match(/403/, assert_raises(RuntimeError) { Substack.fetch }.message) }
    end
  end
end
