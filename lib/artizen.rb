require 'json'

module Artizen
  BASE_URL = 'https://artizen.fund/api/1.1/obj'.freeze
  SITE_URL = 'https://artizen.fund'.freeze
  PAGE_SIZE = 100
  IN_BATCH = 50
  PARALLEL_THREADS = 8
  LEADERBOARD_CACHE = 'artizen/leaderboard/v15'.freeze
  PROJECT_CACHE = 'artizen/project/v13'.freeze
  FUND_CACHE = 'artizen/fund/v8'.freeze

  class << self
    def leaderboard(season_number: nil)
      cache_fetch("#{LEADERBOARD_CACHE}/#{season_number || 'current'}") { build(season_number) }
    rescue StandardError => e
      Honeybadger.notify(e) if defined?(Honeybadger)
      warn "[Artizen] #{e.class}: #{e.message}"
      { seasons: [], season: nil, drives: [], projects: [], funds: [], error: true }
    end

    def project(slug)
      cache_fetch("#{PROJECT_CACHE}/#{slug}") { build_project(slug) }
    rescue StandardError => e
      Honeybadger.notify(e) if defined?(Honeybadger)
      warn "[Artizen] #{e.class}: #{e.message}"
      nil
    end

    def fund(slug)
      cache_fetch("#{FUND_CACHE}/#{slug}") { build_fund(slug) }
    rescue StandardError => e
      Honeybadger.notify(e) if defined?(Honeybadger)
      warn "[Artizen] #{e.class}: #{e.message}"
      nil
    end

    def refresh_cache
      started = Time.now
      seasons = fetch_seasons

      seasons.each do |season|
        puts "[Artizen] leaderboard season #{season[:number]}"
        data = rebuild("#{LEADERBOARD_CACHE}/#{season[:number]}") { build(season[:number]) }
        next if data.nil? || data[:error]

        cache_write("#{LEADERBOARD_CACHE}/current", data) if season[:current]
      end

      dropped = Stash.where(key: /\A#{Regexp.escape(PROJECT_CACHE)}\//).delete_all
      dropped += Stash.where(key: /\A#{Regexp.escape(FUND_CACHE)}\//).delete_all

      puts "[Artizen] refreshed #{seasons.size} seasons, dropped #{dropped} project/fund stashes in #{(Time.now - started).round}s"
    end

    def rich_text(text)
      return if text.blank?

      html = text.to_s.dup
      html.gsub!(%r{\[url=([^\]]+)\](.*?)\[/url\]}m, '<a href="\1" target="_blank" rel="noopener">\2</a>')
      html.gsub!(%r{\[b\](.*?)\[/b\]}m, '<strong>\1</strong>')
      html.gsub!(%r{\[i\](.*?)\[/i\]}m, '<em>\1</em>')
      html.gsub!(%r{\[/?ml\]}, '')
      html.gsub!('[ul]', '<ul>')
      html.gsub!(%r{\[/ul\]}, '</ul>')
      html.gsub!(/\[li[^\]]*\]/, '<li>')
      html.gsub!(%r{\[/li\]}, '</li>')
      html.gsub!(/\r\n?/, "\n")
      html.gsub!(/\n{2,}/, '</p><p>')
      html.gsub!("\n", '<br>')
      "<p>#{html}</p>"
    end

    def video_iframe(url)
      return if url.blank?

      if url =~ %r{(?:youtube\.com/watch\?v=|youtu\.be/)([A-Za-z0-9_-]+)}
        %(<div class="embed-responsive embed-responsive-16by9 mb-3"><iframe class="embed-responsive-item" src="https://www.youtube.com/embed/#{Regexp.last_match(1)}" allowfullscreen></iframe></div>)
      elsif url =~ %r{vimeo\.com/(?:video/)?(\d+)}
        %(<div class="embed-responsive embed-responsive-16by9 mb-3"><iframe class="embed-responsive-item" src="https://player.vimeo.com/video/#{Regexp.last_match(1)}" allowfullscreen></iframe></div>)
      else
        %(<p><a href="#{url}" target="_blank" rel="noopener">Watch presentation</a></p>)
      end
    end

    private

    def build(season_number)
      seasons = fetch_seasons
      season = pick_season(seasons, season_number)
      return { seasons: seasons, season: nil, drives: [], projects: [], funds: [], error: true } unless season

      {
        seasons: seasons,
        season: season,
        drives: fetch_drives(season[:id]),
        projects: project_rows(season[:id]),
        funds: fund_rows(season[:id], current: season[:current]),
        error: false
      }
    end

    def fetch_seasons
      list('season').filter_map do |row|
        number = row['season number']&.to_i
        next if number.nil?

        tag = row['Season tag']
        {
          id: row['_id'],
          number: number,
          title: row['title'] || "Season #{number}",
          tag: tag,
          current: tag.present? && tag != 'Ended',
          total_raised: row['total raised usd']&.to_f,
          competition_start: row['competition start date'],
          competition_end: row['competition end date']
        }
      end.sort_by { |s| -s[:number] }.tap do |seasons|
        current_id = (seasons.find { |s| s[:current] } || seasons.first)&.fetch(:id)
        seasons.each { |s| s[:current] = s[:id] == current_id }
      end
    end

    def pick_season(seasons, season_number)
      found = seasons.find { |s| s[:number] == season_number.to_i } if season_number.present?
      found || seasons.find { |s| s[:current] } || seasons.first
    end

    def project_rows(season_id)
      rows = list(
        'projectseason',
        sort_field: 'funding total',
        descending: true,
        constraints: [
          { key: 'season ', constraint_type: 'equals', value: season_id },
          { key: 'funding total', constraint_type: 'greater than', value: 0 }
        ]
      ).reject { |row| row['hide from competition'] }

      projects = fetch_by_ids('project', rows.map { |r| r['project'] }.compact.uniq).index_by { |p| p['_id'] }

      ranked = rows.filter_map do |row|
        project = projects[row['project']] || {}
        next if project['Hide'] || project['unPublished']

        name = (project['Name'].presence || row['name']).to_s.strip
        next if name.blank?

        slug = project['Slug'].presence || row['project']
        {
          name: name,
          url: local_project_path(slug),
          creator: (project["Lead Creator\t(text)"] || row['lead creator']).to_s.strip.presence,
          logline: project['Logline'].presence,
          sales: row['funding total sales'].to_f,
          match: row['funding match'].to_f + row['funding boost '].to_f,
          prize: row['funding prize funds usd'].to_f,
          raised: row['funding total'].to_f
        }
      end

      ranked.each_with_index.map { |row, i| row.merge(rank: i + 1) }
    end

    def fetch_drives(season_id)
      list(
        'boost',
        constraints: [
          { key: 'season', constraint_type: 'equals', value: season_id },
          { key: 'Type', constraint_type: 'equals', value: 'Fund drive' }
        ]
      ).map { |row| normalize_drive(row) }.sort_by { |drive| -(drive[:number] || 0) }
    end

    def normalize_drive(row)
      slug = row['slugg']
      {
        id: row['_id'],
        name: row['Name'].to_s.strip,
        slug: slug,
        url: "#{SITE_URL}/index/boost/#{slug.presence || row['_id']}",
        season_id: row['season'],
        season_number: row['season number']&.to_i,
        image: media_url(row['image']),
        description: row['Description'].presence,
        status: row['status'],
        active: row['status'] == 'Active',
        number: row['fund drive number']&.to_i,
        start: row['start date'],
        end: row['end date'],
        multiple: row['boost multiple']&.to_f,
        match_pot: row['total match pot funds']&.to_f,
        prize_projects: row['prize pot projects']&.to_f,
        prize_funds: row['prize pot funds']&.to_f,
        project_first: row['project 1st prize ']&.to_f,
        project_second: row['project 2nd prize ']&.to_f,
        project_third: row['project 3rd prize ']&.to_f,
        fund_first: row['fund 1st prize ']&.to_f,
        fund_second: row['fund 2nd prize ']&.to_f,
        fund_third: row['fund 3rd prize ']&.to_f,
        goal: row['goal']&.to_f,
        match_per_project: row['Artizen match per project']&.to_f
      }
    end

    def project_drive_details(drives, stats_by_drive)
      drives.filter_map do |drive|
        stat = stats_by_drive[drive[:id]]
        next unless stat
        next unless stat[:available].to_f.positive? || stat[:raised].to_f.positive? || stat[:sales].to_f.positive?

        stat.merge(
          name: drive[:name],
          status: drive[:status],
          active: drive[:active],
          number: drive[:number],
          url: drive[:url],
          multiple: drive[:multiple],
          season: drive[:season],
          season_id: drive[:season_id],
          season_number: drive[:season_number]
        )
      end
    end

    def nest_project_funding(seasons, drives, matching_funds)
      known = seasons.map { |season| season[:number] }
      drives.each do |drive|
        next if known.include?(drive[:season_number])

        seasons << {
          number: drive[:season_number],
          title: drive[:season] || "Season #{drive[:season_number]}",
          sales: 0.0,
          match: 0.0,
          prize: 0.0,
          raised: 0.0
        }
        known << drive[:season_number]
      end
      matching_funds.each do |fund|
        next if known.include?(fund[:season_number])

        seasons << {
          number: fund[:season_number],
          title: fund[:season] || "Season #{fund[:season_number]}",
          sales: 0.0,
          match: 0.0,
          prize: 0.0,
          raised: 0.0
        }
        known << fund[:season_number]
      end
      seasons.sort_by! { |season| -(season[:number] || 0) }

      seasons.map do |season|
        season_drives = drives.select { |drive| drive[:season_number] == season[:number] }
        season_funds = matching_funds.select { |fund| fund[:season_number] == season[:number] }
        named = season_drives.map { |drive| drive[:name] }
        stubs = season_funds.map { |fund| fund[:drive] }.uniq - named
        stubs.each do |name|
          sample = season_funds.find { |fund| fund[:drive] == name }
          season_drives << {
            name: name,
            url: nil,
            active: sample && sample[:drive_active],
            number: sample && sample[:drive_number],
            sales: 0.0,
            match: 0.0,
            prize: 0.0,
            available: season_funds.select { |fund| fund[:drive] == name }.sum { |fund| fund[:available].to_f },
            multiple: sample && sample[:drive_multiple]
          }
        end
        season_drives.sort_by! { |drive| -(drive[:number] || 0) }
        nested = season_drives.map do |drive|
          drive.merge(
            funds: season_funds.select { |fund| fund[:drive] == drive[:name] }
          )
        end
        season.merge(
          available: nested.sum { |drive| drive[:available].to_f },
          drives: nested
        )
      end
    end

    def nest_fund_funding(contrib_seasons, matched_projects, unallocated: 0)
      seasons = contrib_seasons.map(&:dup)
      known = seasons.map { |season| season[:number] }
      matched_projects.each do |project|
        next if known.include?(project[:season_number])

        seasons << {
          number: project[:season_number],
          title: project[:season] || "Season #{project[:season_number]}",
          total: 0.0,
          count: 0
        }
        known << project[:season_number]
      end
      seasons.sort_by! { |season| -(season[:number] || 0) }

      nested = seasons.map do |season|
        season_projects = matched_projects.select { |project| project[:season_number] == season[:number] }
        drives = season_projects.group_by { |project| project[:drive] || 'Drive' }.map do |name, projects|
          sample = projects.first
          active = sample && sample[:drive_active]
          leftover = projects.sum { |project| project[:available].to_f }
          {
            name: name,
            url: sample && sample[:drive_url],
            active: active,
            number: sample && sample[:drive_number],
            multiple: sample && sample[:drive_multiple],
            unlocked: projects.sum { |project| project[:unlocked].to_f },
            available: active ? leftover : 0.0,
            projects: projects.sort_by { |project| [-project[:available].to_f, -project[:unlocked].to_f] }
          }
        end.sort_by { |drive| -(drive[:number] || 0) }
        season.merge(
          unlocked: drives.sum { |drive| drive[:unlocked] },
          available: drives.sum { |drive| drive[:available] },
          drives: drives
        )
      end

      if unallocated.to_f >= 0.5 && nested.any?
        latest = nested.first
        row = {
          name: 'Unallocated',
          url: nil,
          active: false,
          adjustment: true,
          number: nil,
          multiple: nil,
          unlocked: 0.0,
          available: unallocated.to_f,
          projects: []
        }
        active_idx = latest[:drives].index { |drive| drive[:active] }
        if active_idx
          latest[:drives].insert(active_idx + 1, row)
        else
          latest[:drives] << row
        end
        latest[:available] = latest[:available].to_f + unallocated.to_f
      end

      nested
    end

    def build_project(slug)
      row = find_one('project', slug)
      return if row.nil? || row['Hide']

      id = row['_id']
      slug_value = row['Slug'].presence || id
      seasons_meta = fetch_seasons.index_by { |s| s[:id] }
      season_rows = list('projectseason', constraints: [{ key: 'project', constraint_type: 'equals', value: id }])
      slices = list('projectfundboostslice', constraints: [{ key: 'project', constraint_type: 'equals', value: id }])
      participants = list('boostparticipant', constraints: [{ key: 'project', constraint_type: 'equals', value: id }])

      boost_ids = (slices + participants).map { |r| r['boost'] }.compact.uniq
      drives = fetch_by_ids('boost', boost_ids).map { |r| normalize_drive(r) }
      drives.each do |drive|
        meta = seasons_meta[drive[:season_id]]
        drive[:season_number] ||= meta&.dig(:number)
        drive[:season] = meta&.dig(:title) || (drive[:season_number] && "Season #{drive[:season_number]}")
      end
      drives.sort_by! { |d| [-(d[:season_number] || 0), -(d[:number] || 0)] }

      stats = Hash.new { |h, k| h[k] = {} }
      participants.each do |part|
        next if part['boost'].blank?

        stats[id][part['boost']] = {
          sales: part['fund drive sales (both)'].to_f,
          match: part['match boost unlocked (both)'].to_f,
          raised: part['sales + match (both)'].to_f,
          prize: part['prize earned usd']&.to_f
        }
      end
      slices.group_by { |s| s['boost'] }.each do |boost_id, rows|
        next if boost_id.blank?

        leftover = rows.sum { |r| r['match cap $'].to_f - r['match unlocked'].to_f }
        next unless leftover.positive?

        drive = drives.find { |d| d[:id] == boost_id }
        stats[id][boost_id] ||= { sales: 0.0, match: 0.0, raised: 0.0 }
        stats[id][boost_id][:available] = drive && drive[:active] ? leftover : 0.0
      end

      fund_ids = slices.map { |s| s['fund'] }.compact.uniq
      funds_by_id = fetch_by_ids('fund', fund_ids).index_by { |f| f['_id'] }
      matching_funds = slices.group_by { |s| [s['fund'], s['boost']] }.filter_map do |(fund_id, boost_id), rows|
        fund = funds_by_id[fund_id]
        next unless fund

        drive = drives.find { |d| d[:id] == boost_id }
        fund_slug = fund['Slug'].presence || fund_id
        {
          name: fund['name'].to_s.strip,
          url: local_fund_path(fund_slug),
          drive: drive && drive[:name],
          drive_active: drive && drive[:active],
          drive_number: drive && drive[:number],
          drive_multiple: drive && drive[:multiple],
          season: drive && drive[:season],
          season_number: drive && drive[:season_number],
          available: drive && drive[:active] ? rows.sum { |r| r['match cap $'].to_f - r['match unlocked'].to_f } : 0.0,
          unlocked: rows.sum { |r| r['match unlocked'].to_f },
          cap: rows.sum { |r| r['match cap $'].to_f }
        }
      end.sort_by { |f| [-(f[:season_number] || 0), -(f[:drive_number] || 0), -f[:cap]] }

      tag_ids = Array(row['impact tags (impact tag)'])
      tags = fetch_by_ids('impacttag', tag_ids).map { |t| t['name'] }.compact

      drive_details = project_drive_details(drives, stats[id])
      season_image = season_rows.sort_by { |srow| -(srow['season number'] || 0) }.map { |srow| srow['image crop'] }.find(&:present?)
      seasons = season_rows.filter_map do |srow|
        meta = seasons_meta[srow['season ']]
        s_sales = srow['funding total sales'].to_f
        s_match = srow['funding match'].to_f + srow['funding boost '].to_f
        s_prize = srow['funding prize funds usd'].to_f
        s_raised = s_sales + s_match + s_prize
        next unless s_raised.positive?

        {
          number: srow['season number'] || meta&.dig(:number),
          title: meta&.dig(:title) || "Season #{srow['season number']}",
          sales: s_sales,
          match: s_match,
          prize: s_prize,
          raised: s_raised
        }
      end.sort_by { |s| -(s[:number] || 0) }
      {
        name: row['Name'].to_s.strip,
        artizen_url: project_url(slug_value),
        creator: row["Lead Creator\t(text)"].to_s.strip.presence,
        logline: row['Logline'].presence,
        description: row['Description'].presence,
        impact: row['Impact'].presence,
        progress: row['Progress'].presence,
        team: row['Team'].presence,
        image: media_url(row['(old) Artifact Image -crop'] || season_image || row['Profile image lead creator']),
        video: row['video presentation'].presence,
        tags: tags,
        seasons: nest_project_funding(seasons, drive_details, matching_funds)
      }
    end

    def build_fund(slug)
      row = find_one('fund', slug)
      return unless row

      id = row['_id']
      slug_value = row['Slug'].presence || id
      ext = (get('fundextendedinfo', limit: 1, constraints: [{ key: '_id', constraint_type: 'equals', value: row['Extended info'] }].to_json)['results'] || []).first if row['Extended info']

      slices = list(
        'projectfundboostslice',
        constraints: [
          { key: 'fund', constraint_type: 'equals', value: id },
          { key: 'match cap $', constraint_type: 'greater than', value: 0 }
        ]
      )
      project_ids = slices.map { |s| s['project'] }.compact.uniq
      projects = fetch_by_ids('project', project_ids).index_by { |p| p['_id'] }
      boost_ids = slices.map { |s| s['boost'] }.compact.uniq
      seasons_meta = fetch_seasons.index_by { |s| s[:id] }
      drives = fetch_by_ids('boost', boost_ids).map { |r| normalize_drive(r) }.index_by { |d| d[:id] }
      drives.each_value do |drive|
        meta = seasons_meta[drive[:season_id]]
        drive[:season_number] ||= meta&.dig(:number)
        drive[:season] = meta&.dig(:title) || (drive[:season_number] && "Season #{drive[:season_number]}")
      end

      matched_projects = slices.group_by { |s| [s['project'], s['boost']] }.filter_map do |(project_id, boost_id), rows|
        project = projects[project_id]
        next unless project && !project['Hide'] && !project['unPublished']

        drive = drives[boost_id]
        project_slug = project['Slug'].presence || project_id
        {
          name: project['Name'].to_s.strip,
          url: local_project_path(project_slug),
          creator: project["Lead Creator\t(text)"].to_s.strip.presence,
          drive: drive && drive[:name],
          drive_url: drive && drive[:url],
          drive_active: drive && drive[:active],
          drive_number: drive && drive[:number],
          drive_multiple: drive && drive[:multiple],
          season: drive && drive[:season],
          season_number: drive && drive[:season_number],
          available: rows.sum { |r| r['match cap $'].to_f - r['match unlocked'].to_f },
          unlocked: rows.sum { |r| r['match unlocked'].to_f }
        }
      end

      contribs = list(
        'fundcontribution',
        constraints: [
          { key: 'Fund', constraint_type: 'equals', value: id },
          { key: 'confirmed', constraint_type: 'equals', value: true }
        ]
      )
      contrib_seasons = contribs.group_by { |c| c['Season'] }.filter_map do |season_id, rows|
        meta = seasons_meta[season_id]
        {
          number: meta&.dig(:number),
          title: meta&.dig(:title) || 'Season',
          total: rows.sum { |r| r['amount $USD'].to_f },
          count: rows.size
        }
      end

      contrib_total = contribs.sum { |c| c['amount $USD'].to_f }
      sliced_available = matched_projects.select { |project| project[:drive_active] }.sum { |project| project[:available].to_f }
      unallocated = row['Funding - current'].to_f - sliced_available
      seasons = nest_fund_funding(contrib_seasons, matched_projects, unallocated: unallocated)

      {
        name: (ext && ext['full title'].presence) || row['name'].to_s.strip,
        artizen_url: fund_url(slug_value),
        image: media_url(row['cover image']),
        subtitle: ext && ext['subtitle'].presence,
        for_title: ext && ext['for title'].presence,
        description: ext && ext['description'].presence,
        eligibility: ext && ext['eligibility'].presence,
        sponsor: ext && ext['lead sponsor (text)'].presence,
        video: ext && ext['welcome video'].presence,
        available: seasons.sum { |season| season[:available].to_f },
        unlocked: seasons.sum { |season| season[:unlocked].to_f },
        prize_art: row['Prize ART']&.to_f,
        prize_usd: row['Prize USD']&.to_f,
        active: row['active'],
        contrib_total: contrib_total,
        seasons: seasons
      }
    end

    def find_one(type, slug, slug_field: 'Slug')
      rows = get(type, limit: 5, constraints: [{ key: slug_field, constraint_type: 'equals', value: slug }].to_json)['results'] || []
      row = rows.find { |r| !r['Hide'] && !r['unPublished'] } || rows.first
      return row if row

      (get(type, limit: 1, constraints: [{ key: '_id', constraint_type: 'equals', value: slug }].to_json)['results'] || []).first
    end

    def fund_rows(season_id, current: false)
      contribs = list(
        'fundcontribution',
        constraints: [
          { key: 'Season', constraint_type: 'equals', value: season_id },
          { key: 'confirmed', constraint_type: 'equals', value: true }
        ]
      )

      totals = Hash.new(0.0)
      last_at = {}
      contribs.each do |contrib|
        id = contrib['Fund']
        next if id.blank?

        totals[id] += contrib['amount $USD'].to_f
        created = contrib['Created Date']
        last_at[id] = created if created && (last_at[id].nil? || created > last_at[id])
      end

      funds = fetch_by_ids('fund', totals.keys)
      unlocked = current ? fund_unlocked(totals.keys) : {}
      exts = fetch_by_ids('fundextendedinfo', funds.map { |fund| fund['Extended info'] }).index_by { |row| row['_id'] }
      ranked = funds.filter_map do |fund|
        id = fund['_id']
        season_total = totals[id].to_f
        next unless season_total.positive?

        slug = fund['Slug'].presence || id
        ext = exts[fund['Extended info']]
        row = {
          name: fund['name'].to_s.strip,
          subtitle: ext && ext['subtitle'].presence,
          url: local_fund_path(slug),
          season_total: season_total,
          last_contribution: last_at[id],
          active: fund['active']
        }
        if current
          row[:unlocked] = unlocked[id].to_f
          row[:available] = fund['Funding - current']&.to_f
          row[:raised] = row[:available].to_f + row[:unlocked]
          row[:prize_art] = fund['Prize ART']&.to_f
          row[:prize_usd] = fund['Prize USD']&.to_f
        end
        row
      end
      ranked.sort_by! do |row|
        current ? [-row[:available].to_f, -row[:season_total]] : [-row[:season_total]]
      end

      ranked.each_with_index.map { |row, i| row.merge(rank: i + 1) }
    end

    def fund_unlocked(fund_ids)
      unlocked = Hash.new(0.0)
      fund_ids.compact.uniq.each_slice(IN_BATCH) do |batch|
        list(
          'projectfundboostslice',
          constraints: [
            { key: 'fund', constraint_type: 'in', value: batch },
            { key: 'match unlocked', constraint_type: 'greater than', value: 0 }
          ]
        ).each do |slice|
          unlocked[slice['fund']] += slice['match unlocked'].to_f
        end
      end
      unlocked
    end

    def list(type, constraints: nil, sort_field: nil, descending: nil)
      params = { limit: PAGE_SIZE }
      params[:constraints] = constraints.to_json if constraints
      params[:sort_field] = sort_field if sort_field
      params[:descending] = true if descending

      first = get(type, params.merge(cursor: 0))
      results = first['results'] || []
      remaining = first['remaining'].to_i
      return results if remaining <= 0

      cursors = 1.upto((remaining.to_f / PAGE_SIZE).ceil).map { |i| i * PAGE_SIZE }
      extra = parallel(cursors) { |cursor| get(type, params.merge(cursor: cursor))['results'] || [] }
      results + extra.flatten
    end

    def fetch_by_ids(type, ids)
      ids = ids.compact.uniq
      return [] if ids.empty?

      pages = parallel(ids.each_slice(IN_BATCH).to_a) do |batch|
        get(type, limit: PAGE_SIZE, constraints: [{ key: '_id', constraint_type: 'in', value: batch }].to_json)['results'] || []
      end
      pages.flatten
    end

    def get(type, params)
      response = Faraday.get("#{BASE_URL}/#{type}", params) do |req|
        req.options.timeout = 25
        req.options.open_timeout = 5
        req.headers['Accept'] = 'application/json'
      end
      raise "Artizen API #{response.status} for #{type}" unless response.success?

      JSON.parse(response.body).fetch('response')
    end

    def parallel(items)
      return [] if items.empty?
      return [yield(items.first)] if items.size == 1

      work = items.map.with_index { |item, i| [i, item] }
      results = Array.new(items.size)
      mutex = Mutex.new
      workers = [PARALLEL_THREADS, work.size].min.times.map do
        Thread.new do
          loop do
            i, item = mutex.synchronize { work.shift }
            break unless i

            results[i] = yield item
          end
        end
      end
      workers.each(&:join)
      results
    end

    def cache_fetch(key, &block)
      if (stash = Stash.find_by(key: key))
        return JSON.parse(stash.value, symbolize_names: true)
      end

      cache_write(key, &block)
    end

    def cache_write(key, value = nil)
      value = yield if block_given?
      if value && !(value.is_a?(Hash) && value[:error])
        stash = Stash.find_or_initialize_by(key: key)
        stash.value = value.to_json
        stash.save!
      end
      value
    end

    def rebuild(key)
      cache_write(key) { yield }
    rescue StandardError => e
      Honeybadger.notify(e) if defined?(Honeybadger)
      warn "[Artizen] #{key} failed: #{e.class}: #{e.message}"
      nil
    end

    def project_url(slug_or_id)
      "#{SITE_URL}/index/p/#{slug_or_id}"
    end

    def fund_url(slug_or_id)
      "#{SITE_URL}/index/mf/#{slug_or_id}"
    end

    def local_project_path(slug_or_id)
      "/artizen/projects/#{slug_or_id}"
    end

    def local_fund_path(slug_or_id)
      "/artizen/funds/#{slug_or_id}"
    end

    def media_url(path)
      return if path.blank?

      path.start_with?('//') ? "https:#{path}" : path
    end
  end
end
