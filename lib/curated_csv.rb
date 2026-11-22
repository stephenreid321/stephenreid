# A CSV in data/iconomi/ that you edit by hand, with a row per ticker: what you've decided about ICONOMI's assets and strategies
class CuratedCsv
  attr_reader :path, :columns

  def initialize(name, columns, dir: File.join(ROOT, 'data'))
    @path = File.join(dir, "#{name}.csv")
    @columns = columns
  end

  # Each row, by ticker, with blanks as nil
  def rows
    return {} unless File.exist?(path)

    CSV.read(path, headers: true, encoding: 'UTF-8').to_h do |row|
      [row['ticker'], row.to_h.transform_values(&:presence)]
    end
  end

  # Adds a row for each of these tickers that hasn't got one, with these values, and sets the status of those with
  # none. Returns the tickers it added or changed
  def verify(names)
    rows = self.rows
    changed = names.filter_map do |ticker, name|
      next if rows[ticker] && rows[ticker]['status']

      rows[ticker] = (rows[ticker] || { 'ticker' => ticker, 'name' => name }).merge('status' => 'verified')
      ticker
    end
    write(rows)
    changed
  end

  def write(rows)
    CSV.open(path, 'w', encoding: 'UTF-8') do |csv|
      csv << columns
      rows.values.sort_by { |row| row['ticker'] }.each { |row| csv << columns.map { |c| row[c] } }
    end
  end
end

# An ICONOMI strategy or asset, whose status (verified or excluded, or none yet) is decided by hand in its CSV in
# data/iconomi/, named for its class (strategies.csv, assets.csv), with its class's CSV_COLUMNS
module Curated
  def self.included(base)
    base.extend(ClassMethods)
  end

  def verified?
    status == 'verified'
  end

  module ClassMethods
    def csv_file
      CuratedCsv.new("iconomi/#{name.underscore.pluralize}", self::CSV_COLUMNS)
    end

    # Forgets what it read, to read it again
    def reset!
      @all = nil
    end
  end
end
