# A coin on ICONOMI. Its name comes from the strategies' holdings (data/fetched/iconomi.json); its status, multiplier
# and colour from data/iconomi_assets.csv, which you edit by hand
class Asset
  attr_reader :ticker, :name, :status, :multiplier, :color

  def initialize(ticker:, name: nil, status: nil, multiplier: nil, color: nil)
    @ticker = ticker
    @name = name
    @status = status
    @multiplier = multiplier&.to_f
    @color = color
  end

  def virtual_color
    Digest::MD5.hexdigest(ticker)[0..5].paint.opacity(0.5).to_rgb
  end

  # Its colour for a badge or chart
  def css_color
    color ? "##{color}" : virtual_color
  end

  def verified?
    status == 'verified'
  end

  # Its multiplier as the badge shows it: 2x, 0.5x
  def multiplier_label
    "#{multiplier == multiplier.to_i ? multiplier.to_i : multiplier}x" if multiplier
  end

  def self.statuses
    ['', 'verified', 'excluded']
  end

  class << self
    def csv_file
      CuratedCsv.new('iconomi_assets', %w[ticker name status multiplier color])
    end

    # Each asset, by ticker
    def all
      @all ||= begin
        names = Fetched.read(:iconomi, {}).fetch('assets', {})
        rows = csv_file.rows
        (names.keys | rows.keys).to_h do |ticker|
          row = rows.fetch(ticker, {})
          [ticker, new(ticker: ticker, name: names[ticker] || row['name'], status: row['status'], multiplier: row['multiplier'], color: row['color'])]
        end
      end
    end

    def find_by_ticker(ticker)
      all[ticker] || new(ticker: ticker)
    end

    def reset!
      @all = nil
    end
  end
end
