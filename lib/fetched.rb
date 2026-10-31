# What the data tasks fetch from other sites (Substack, ICONOMI, Google Maps, the courses' repo), as JSON files in
# data/fetched. It isn't committed: CI keeps it between builds in its cache, and each build of the site reads it
module Fetched
  DIR = File.join(ROOT, 'data', 'fetched')

  def self.path(name)
    File.join(DIR, "#{name}.json")
  end

  def self.exist?(name)
    File.exist?(path(name))
  end

  def self.read(name, default = [])
    exist?(name) ? JSON.parse(File.read(path(name), encoding: 'UTF-8')) : default
  end

  def self.write(name, data)
    FileUtils.mkdir_p(DIR)
    File.write(path(name), JSON.generate(data))
  end
end
