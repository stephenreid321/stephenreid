class Snapshot
  include Mongoid::Document
  include Mongoid::Timestamps

  field :wallet, :type => String
  field :currency, :type => String
  field :units, :type => Float
  field :usd_per_unit, :type => Float
  field :gbp_per_unit, :type => Float
      
  validates_presence_of :wallet, :currency, :units, :usd_per_unit, :gbp_per_unit
        
  def self.admin_fields
    {
      :wallet => :text,
      :currency => :text,
      :units => :number,
      :usd_per_unit => :number,
      :gbp_per_unit => :number
    }
  end
    
end
