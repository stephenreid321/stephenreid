class TarotCard
  include Mongoid::Document
  include Mongoid::Timestamps

  field :name, :type => String
  field :description, :type => String
  field :teachmetarot_url, :type => String
  
  belongs_to :tarot_number
  belongs_to :tarot_suit, optional: true  
  
  def self.majors
    ['fool', 'magician', 'high priestess', 'empress', 'emperor', 'hierophant', 'lovers', 'chariot', 'strength', 'hermit', 'wheel of fortune',
      'justice', 'hanged man', 'death', 'temperance', 'devil', 'tower', 'star', 'moon', 'sun', 'judgement', 'world']
  end
  
  def self.admin_fields
    {
      :name => :text,
      :tarot_number_id => :lookup,
      :tarot_suit_id => :lookup,      
      :teachmetarot_url => :url,
      :description => :text_area
    }
  end 
    
end
