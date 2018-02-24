class TarotSuit
  include Mongoid::Document
  include Mongoid::Timestamps

  field :name, :type => String
  field :description, :type => String
  field :teachmetarot_url, :type => String
  
  has_many :tarot_cards, :dependent => :destroy
  
  def self.admin_fields
    {
      :name => :text,
      :description => :text_area,
      :teachmetarot_url => :url,
      :tarot_cards => :collection
    }
  end
  
  def self.suits
    %w{swords wands cups pentacles}
  end
  
  def self.icons
    {:swords => ['air', :cloud], :wands => ['fire', :fire], :cups => ['water', :tint], :pentacles => ['earth', :globe]}
  end    
    
end
