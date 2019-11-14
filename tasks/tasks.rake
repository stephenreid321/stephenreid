namespace :terms do
  
  task :create_edges => :environment do
    term_ids = []
    Post.all(filter: "IS_AFTER({Created at}, '#{1.day.ago.to_s(:db)}')").each { |post|
      term_ids += post['Terms'] if post['Terms']
    }    
    term_ids.uniq.each { |term_id|      
      term = Term.find(term_id)
      puts term['Name']
      term.create_edges 
    }
  end
    
end