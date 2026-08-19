require 'json'

module Artizen
  BASE_URL = 'https://artizen.fund/api/1.1/obj'.freeze
  SITE_URL = 'https://artizen.fund'.freeze
  PAGE_SIZE = 100
  IN_BATCH = 50
  PARALLEL_THREADS = 8
  LEADERBOARD_CACHE = 'artizen/leaderboard/v25'.freeze
  PROJECT_CACHE = 'artizen/project/v19'.freeze
  FUND_CACHE = 'artizen/fund/v10'.freeze
  VENUS_ACCOUNT_ID = '1774215063859x668765896046542800'.freeze

  class << self
    def leaderboard(season_number: nil)
      with_artizen_errors({ seasons: [], season: nil, drives: [], projects: [], funds: [], error: true }) do
        cache_fetch("#{LEADERBOARD_CACHE}/#{season_number || 'current'}") { build(season_number) }
      end
    end

    def project(slug)
      with_artizen_errors(nil) { cache_fetch("#{PROJECT_CACHE}/#{slug}") { build_project(slug) } }
    end

    def fund(slug)
      with_artizen_errors(nil) { cache_fetch("#{FUND_CACHE}/#{slug}") { build_fund(slug) } }
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

      dropped = Stash.where(key: %r{\A#{Regexp.escape(PROJECT_CACHE)}/}).delete_all
      dropped += Stash.where(key: %r{\A#{Regexp.escape(FUND_CACHE)}/}).delete_all

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
        projects: project_rows(season),
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

    def project_rows(season)
      season_id = season[:id]
      rows = list(
        'projectseason',
        sort_field: 'funding total',
        descending: true,
        constraints: [
          { key: 'season ', constraint_type: 'equals', value: season_id },
          { key: 'funding total', constraint_type: 'greater than', value: 0 }
        ]
      ).reject { |row| row['hide from competition'] }
      return legacy_season_project_rows(season) if rows.empty?

      projects = indexed('project', rows.map { |r| r['project'] })
      venus_by_project = venus_buys_by_project(season_id)
      prizes = drive_prizes_by_project(season_id)

      rows.filter_map do |row|
        project = projects[row['project']] || {}
        next if project['Hide'] || project['unPublished']

        name = (project['Name'].presence || row['name']).to_s.strip
        next if name.blank?

        slug = project['Slug'].presence || row['project']
        venus = venus_by_project[row['project']].to_f
        ledger_prize = row['funding prize funds usd'].to_f
        prize = [ledger_prize, prizes[row['project']]].max
        {
          name: name,
          url: local_project_path(slug),
          creator: (project["Lead Creator\t(text)"] || row['lead creator']).to_s.strip.presence,
          logline: project['Logline'].presence,
          sales: community_sales(row['funding total sales'], venus),
          venus: venus,
          match: row['funding match'].to_f + row['funding boost '].to_f,
          prize: prize,
          raised: row['funding total'].to_f + prize - ledger_prize
        }
      end
    end

    def fetch_drives(season_id)
      drives = list(
        'boost',
        constraints: [
          { key: 'season', constraint_type: 'equals', value: season_id },
          { key: 'Type', constraint_type: 'equals', value: 'Fund drive' }
        ]
      ).map { |row| normalize_drive(row) }.sort_by { |drive| -(drive[:number] || 0) }
      attach_drive_podiums(drives)
      drives
    end

    def attach_drive_podiums(drives)
      return if drives.empty?

      pages = parallel(drives) do |drive|
        get_results(
          'boostparticipant',
          limit: 100,
          cursor: 0,
          sort_field: 'boost score',
          descending: true,
          constraints: [{ key: 'boost', constraint_type: 'equals', value: drive[:id] }].to_json
        )
      end
      records = pages.flatten
      catalogs = {
        project: indexed('project', records.map { |row| row['project'] }),
        fund: indexed('fund', records.map { |row| row['fund'] })
      }
      drives.zip(pages).each do |drive, rows|
        drive[:podium] = podium_rows(rows, :project, catalogs[:project])
        drive[:fund_podium] = podium_rows(rows, :fund, catalogs[:fund])
      end
    end

    def podium_rows(rows, kind, records)
      field = kind.to_s
      name_field = kind == :fund ? 'name' : 'Name'
      rows.filter_map do |row|
        next if kind == :fund && row['project'].present?

        id = row[field]
        next if id.blank?

        record = records[id]
        slug = (record && (record['Slug'] || record['slugg']).presence) || id
        points = row['boost points received'].to_f
        sales_match = row['sales + match (both)'].to_f
        {
          name: (record && record[name_field]).to_s.strip.presence || field.capitalize,
          url: kind == :fund ? local_fund_path(slug) : local_project_path(slug),
          sales_match: sales_match,
          points: points,
          score: points * sales_match / 100.0
        }
      end.first(3)
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
        goal: row['goal']&.to_f,
        match_per_project: row['Artizen match per project']&.to_f
      }.merge(drive_place_prizes(row))
    end

    def drive_place_prizes(row)
      %w[project fund].flat_map do |kind|
        [%w[first 1st], %w[second 2nd], %w[third 3rd]].map do |ord, nth|
          [:"#{kind}_#{ord}", row["#{kind} #{nth} prize "]&.to_f]
        end
      end.to_h
    end

    def project_drive_details(drives, stats_by_drive)
      drives.filter_map do |drive|
        stat = stats_by_drive[drive[:id]]
        next unless stat
        next unless stat[:available].to_f.positive? || stat[:raised].to_f.positive? || stat[:sales].to_f.positive? || stat[:venus].to_f.positive?

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
      (drives + matching_funds).each do |row|
        next if known.include?(row[:season_number])

        seasons << {
          number: row[:season_number],
          title: row[:season] || "Season #{row[:season_number]}",
          sales: 0.0,
          venus: 0.0,
          match: 0.0,
          prize: 0.0,
          raised: 0.0
        }
        known << row[:season_number]
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
            venus: 0.0,
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
      seasons_meta = seasons_by_id
      season_rows = list('projectseason', constraints: [{ key: 'project', constraint_type: 'equals', value: id }])
      slices = list('projectfundboostslice', constraints: [{ key: 'project', constraint_type: 'equals', value: id }])
      participants = list('boostparticipant', constraints: [{ key: 'project', constraint_type: 'equals', value: id }])

      boost_ids = (slices + participants).map { |r| r['boost'] }.compact.uniq
      drives = fetch_normalized_drives(boost_ids, seasons_meta)
      drives.sort_by! { |d| [-(d[:season_number] || 0), -(d[:number] || 0)] }

      venus_txs = venus_transactions(project_id: id)
      venus_by_season = Hash.new(0.0)
      venus_by_boost = Hash.new(0.0)
      venus_txs.each do |tx|
        venus_by_season[tx['Season']] += tx['amount spent $USD'].to_f
        drive = assign_venus_drive(tx, drives)
        venus_by_boost[drive[:id]] += tx['amount spent $USD'].to_f if drive
      end

      prize_by_season = Hash.new(0.0)
      stats = Hash.new { |h, k| h[k] = {} }
      participants.each do |part|
        next if part['boost'].blank?

        venus = venus_by_boost[part['boost']].to_f
        prize = part['prize earned usd'].to_f
        stats[id][part['boost']] = {
          sales: community_sales(part['fund drive sales (both)'], venus),
          venus: venus,
          match: part['match boost unlocked (both)'].to_f,
          prize: prize,
          raised: part['sales + match (both)'].to_f + prize
        }
        season_id = part['season']
        if season_id.blank?
          drive = drives.find { |d| d[:id] == part['boost'] }
          season_id = drive && drive[:season_id]
        end
        prize_by_season[season_id] += prize if season_id && prize.positive?
      end
      slices.group_by { |s| s['boost'] }.each do |boost_id, rows|
        next if boost_id.blank?

        leftover = leftover_match(rows)
        next unless leftover.positive?

        drive = drives.find { |d| d[:id] == boost_id }
        stats[id][boost_id] ||= { sales: 0.0, venus: 0.0, match: 0.0, raised: 0.0 }
        stats[id][boost_id][:available] = drive && drive[:active] ? leftover : 0.0
      end

      fund_ids = slices.map { |s| s['fund'] }.compact.uniq
      funds_by_id = indexed('fund', fund_ids)
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
          available: drive && drive[:active] ? leftover_match(rows) : 0.0,
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
        s_venus = venus_by_season[srow['season ']].to_f
        s_sales = community_sales(srow['funding total sales'], s_venus)
        s_match = srow['funding match'].to_f + srow['funding boost '].to_f
        s_prize = [
          srow['funding prize funds usd'].to_f,
          prize_by_season[srow['season ']],
          srow['old funding prize leaderboard  (usd)'].to_f
        ].max
        s_raised = s_sales + s_venus + s_match + s_prize
        next unless s_raised.positive?

        {
          number: srow['season number'] || meta&.dig(:number),
          title: meta&.dig(:title) || "Season #{srow['season number']}",
          sales: s_sales,
          venus: s_venus,
          match: s_match,
          prize: s_prize,
          raised: s_raised
        }
      end
      submission_rows = list('projectsubmission', constraints: [{ key: 'Project', constraint_type: 'equals', value: id }])
      append_legacy_project_seasons(seasons, row, seasons_meta)
      apply_legacy_submission_awards(seasons, submission_rows, seasons_meta)
      seasons.sort_by! { |s| -(s[:number] || 0) }
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
        seasons: nest_project_funding(seasons, drive_details, matching_funds),
        submissions: format_project_submissions(submission_rows, seasons_meta)
      }
    end

    def format_project_submissions(rows, seasons_meta)
      rows = rows.reject { |row| row['Submitted'] == false }
      fund_ids = rows.map { |row| row['Fund'] }.compact.uniq
      funds_by_id = indexed('fund', fund_ids)
      rows.filter_map do |row|
        fund = funds_by_id[row['Fund']]
        next unless fund

        slug = fund['Slug'].presence || row['Fund']
        meta = seasons_meta[row['season']]
        number = row['season number'] || meta&.dig(:number)
        {
          name: fund['name'].to_s.strip,
          url: local_fund_path(slug),
          status: row['Status'].to_s.presence,
          season: meta&.dig(:title) || (number && "Season #{number}"),
          season_number: number,
          created_at: row['Created Date']
        }
      end.sort do |a, b|
        cmp = (b[:season_number] || 0) <=> (a[:season_number] || 0)
        next cmp unless cmp.zero?

        cmp = submission_status_rank(a[:status]) <=> submission_status_rank(b[:status])
        cmp.zero? ? b[:created_at].to_s <=> a[:created_at].to_s : cmp
      end
    end

    def submission_status_rank(status)
      case status
      when 'Curated', 'Approved' then 0
      when 'Submitted' then 1
      else 2
      end
    end

    def build_fund(slug)
      row = find_one('fund', slug)
      return unless row

      id = row['_id']
      slug_value = row['Slug'].presence || id
      ext = find_by('fundextendedinfo', '_id', row['Extended info']).first if row['Extended info']

      slices = list(
        'projectfundboostslice',
        constraints: [
          { key: 'fund', constraint_type: 'equals', value: id },
          { key: 'match cap $', constraint_type: 'greater than', value: 0 }
        ]
      )
      award_rows = list_fund_awards([id])
      project_ids = (slices.map { |s| s['project'] } + award_rows.map { |s| s['Project'] }).compact.uniq
      projects = indexed('project', project_ids)
      boost_ids = slices.map { |s| s['boost'] }.compact.uniq
      seasons_meta = seasons_by_id
      drives = fetch_normalized_drives(boost_ids, seasons_meta).index_by { |d| d[:id] }

      matched_projects = slices.group_by { |s| [s['project'], s['boost']] }.filter_map do |(project_id, boost_id), rows|
        project = projects[project_id]
        next unless project

        drive = drives[boost_id]
        project_slug = project['Slug'].presence || project_id
        {
          name: project['Name'].to_s.strip,
          url: local_project_path(project_slug),
          creator: project["Lead Creator\t(text)"].to_s.strip.presence,
          hidden: project['Hide'] || project['unPublished'],
          drive: drive && drive[:name],
          drive_url: drive && drive[:url],
          drive_active: drive && drive[:active],
          drive_number: drive && drive[:number],
          drive_multiple: drive && drive[:multiple],
          season: drive && drive[:season],
          season_number: drive && drive[:season_number],
          available: leftover_match(rows),
          unlocked: rows.sum { |r| r['match unlocked'].to_f }
        }
      end
      matched_projects.concat(fund_award_projects(award_rows, projects, seasons_meta))

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
      rows = find_by(type, slug_field, slug, limit: 5)
      row = rows.find { |r| !r['Hide'] && !r['unPublished'] } || rows.first
      return row if row

      find_by(type, '_id', slug).first
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
      exts = indexed('fundextendedinfo', funds.map { |fund| fund['Extended info'] })
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
        end
        row
      end
      ranked.sort_by! do |row|
        current ? [-row[:available].to_f, -row[:season_total]] : [-row[:season_total]]
      end
    end

    def fund_unlocked(fund_ids)
      unlocked = Hash.new(0.0)
      ids = fund_ids.compact.uniq
      ids.each_slice(IN_BATCH) do |batch|
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
      list_fund_awards(ids).each do |row|
        unlocked[row['Fund']] += row['$ amount raised'].to_f
      end
      unlocked
    end

    def list_fund_awards(fund_ids)
      ids = fund_ids.compact.uniq
      return [] if ids.empty?

      pages = parallel(ids.each_slice(IN_BATCH).to_a) do |batch|
        list(
          'projectsubmission',
          constraints: [
            { key: 'Fund', constraint_type: 'in', value: batch },
            { key: 'Status', constraint_type: 'equals', value: 'Curated' },
            { key: '$ amount raised', constraint_type: 'greater than', value: 0 }
          ]
        )
      end
      pages.flatten
    end

    def fund_award_projects(award_rows, projects, seasons_meta)
      award_rows.group_by do |row|
        number = row['season number'] || seasons_meta[row['season']]&.dig(:number)
        [row['Project'], number]
      end.filter_map do |(project_id, number), rows|
        raised = rows.sum { |row| row['$ amount raised'].to_f }
        next unless raised.positive? && number

        project = projects[project_id]
        meta = seasons_meta[rows.first['season']]
        project_slug = (project && project['Slug'].presence) || project_id
        {
          name: (project && project['Name']).to_s.strip.presence || 'Project',
          url: local_project_path(project_slug),
          creator: project && project["Lead Creator\t(text)"].to_s.strip.presence,
          hidden: project && (project['Hide'] || project['unPublished']),
          drive: 'Awards',
          drive_url: nil,
          drive_active: false,
          drive_number: nil,
          drive_multiple: nil,
          season: meta&.dig(:title) || "Season #{number}",
          season_number: number,
          available: 0.0,
          unlocked: raised
        }
      end
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
      extra = parallel(cursors) { |cursor| get_results(type, params.merge(cursor: cursor)) }
      results + extra.flatten
    end

    def fetch_by_ids(type, ids)
      ids = ids.compact.uniq
      return [] if ids.empty?

      pages = parallel(ids.each_slice(IN_BATCH).to_a) do |batch|
        get_results(type, limit: PAGE_SIZE, constraints: [{ key: '_id', constraint_type: 'in', value: batch }].to_json)
      end
      pages.flatten
    end

    def indexed(type, ids)
      fetch_by_ids(type, ids).index_by { |row| row['_id'] }
    end

    def seasons_by_id
      fetch_seasons.index_by { |s| s[:id] }
    end

    def fetch_normalized_drives(boost_ids, seasons_meta)
      drives = fetch_by_ids('boost', boost_ids).map { |r| normalize_drive(r) }
      apply_season_names(drives, seasons_meta)
      drives
    end

    def leftover_match(rows)
      rows.sum { |r| r['match cap $'].to_f - r['match unlocked'].to_f }
    end

    def with_artizen_errors(fallback, context: nil)
      yield
    rescue StandardError => e
      Honeybadger.notify(e) if defined?(Honeybadger)
      prefix = context ? "#{context} failed: " : ''
      warn "[Artizen] #{prefix}#{e.class}: #{e.message}"
      fallback
    end

    def get(type, params)
      response = Faraday.get("#{BASE_URL}/#{type}", params) do |req|
        req.options.timeout = 60
        req.options.open_timeout = 5
        req.headers['Accept'] = 'application/json'
      end
      raise "Artizen API #{response.status} for #{type}" unless response.success?

      JSON.parse(response.body).fetch('response')
    end

    def get_results(type, params)
      get(type, params)['results'] || []
    end

    def find_by(type, key, value, limit: 1)
      get_results(type, limit: limit, constraints: [{ key: key, constraint_type: 'equals', value: value }].to_json)
    end

    def parallel(items)
      return [] if items.empty?
      return [yield(items.first)] if items.size == 1

      work = items.map.with_index { |item, i| [i, item] }
      results = Array.new(items.size)
      error = nil
      mutex = Mutex.new
      workers = [PARALLEL_THREADS, work.size].min.times.map do
        Thread.new do
          loop do
            break if error

            i, item = mutex.synchronize { work.shift }
            break unless i

            begin
              results[i] = yield item
            rescue StandardError => e
              mutex.synchronize { error ||= e }
              break
            end
          end
        end
      end
      workers.each(&:join)
      raise error if error

      results
    end

    def cache_fetch(key, &)
      return yield if Padrino.env == :development

      if (stash = Stash.find_by(key: key))
        return JSON.parse(stash.value, symbolize_names: true)
      end

      cache_write(key, &)
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

    def rebuild(key, &)
      with_artizen_errors(nil, context: key) { cache_write(key, &) }
    end

    def venus_account_id
      return @venus_account_id if defined?(@venus_account_id)

      rows = find_by('useraccount', 'name', 'Venus')
      @venus_account_id = rows.dig(0, '_id') || VENUS_ACCOUNT_ID
    end

    def venus_transactions(season_id: nil, project_id: nil)
      id = venus_account_id
      return [] if id.blank?

      constraints = [
        { key: 'Buyer (User account)', constraint_type: 'equals', value: id },
        { key: 'confirmed', constraint_type: 'equals', value: true }
      ]
      constraints << { key: 'Season', constraint_type: 'equals', value: season_id } if season_id
      constraints << { key: 'project', constraint_type: 'equals', value: project_id } if project_id
      list('transaction', constraints: constraints)
    end

    def venus_buys_by_project(season_id)
      venus_transactions(season_id: season_id).each_with_object(Hash.new(0.0)) do |tx, sums|
        pid = tx['project']
        next if pid.blank?

        sums[pid] += tx['amount spent $USD'].to_f
      end
    end

    def drive_prizes_by_project(season_id)
      list(
        'boostparticipant',
        constraints: [
          { key: 'season', constraint_type: 'equals', value: season_id },
          { key: 'prize earned usd', constraint_type: 'greater than', value: 0 }
        ]
      ).each_with_object(Hash.new(0.0)) do |part, sums|
        pid = part['project']
        next if pid.blank?

        sums[pid] += part['prize earned usd'].to_f
      end
    end

    def assign_venus_drive(tx, drives)
      created = parse_time(tx['Created Date'])
      return unless created

      candidates = drives.select { |drive| drive[:season_id] == tx['Season'] }
      candidates = drives if candidates.empty?

      in_window = candidates.select do |drive|
        start = parse_time(drive[:start])
        finish = parse_time(drive[:end])
        next false unless start

        created >= start && (finish.nil? || created <= finish)
      end
      return in_window.max_by { |drive| parse_time(drive[:start]) } if in_window.any?

      started = candidates.select { |drive| (start = parse_time(drive[:start])) && start <= created }
      started.max_by { |drive| parse_time(drive[:start]) }
    end

    def parse_time(value)
      return if value.blank?

      Time.parse(value.to_s)
    rescue ArgumentError
      nil
    end

    def community_sales(gross, venus)
      sales = gross.to_f - venus.to_f
      sales.positive? ? sales : 0.0
    end

    # S4/S5 predate projectseason; Artizen stores them on the project record.
    # A later projectseason stub may exist with sales but no prize/match — merge, don't skip.
    def append_legacy_project_seasons(seasons, project, seasons_meta)
      by_number = seasons_meta.values.index_by { |meta| meta[:number] }
      existing = seasons.index_by { |season| season[:number] }
      [4, 5].each do |number|
        funding = legacy_season_funding(project, number)
        next unless funding && funding[:raised].to_f.positive?

        if (row = existing[number])
          row[:sales] = [row[:sales].to_f, funding[:sales].to_f].max
          row[:match] = [row[:match].to_f, funding[:match].to_f].max
          row[:prize] = [row[:prize].to_f, funding[:prize].to_f].max
          row[:raised] = row[:sales] + row[:venus].to_f + row[:match] + row[:prize]
        else
          meta = by_number[number]
          seasons << funding.merge(
            number: number,
            title: meta&.dig(:title) || "Season #{number}"
          )
        end
      end
    end

    def legacy_season_funding(project, number)
      case number
      when 4
        raised = project['season 4 total raised '].to_f
        match = project['season 4 match funding'].to_f
        sales = [raised - match, 0.0].max
        { sales: sales, venus: 0.0, match: match, prize: 0.0, raised: raised }
      when 5
        sales = project['season 5 total sales'].to_f
        prize = project['season 5 leaderboard prize (usd)'].to_f
        { sales: sales, venus: 0.0, match: 0.0, prize: prize, raised: sales + prize }
      end
    end

    # S4/S5 fund awards live on curated submissions, not projectseason match/prize.
    def apply_legacy_submission_awards(seasons, submission_rows, seasons_meta)
      awards = Hash.new { |h, k| h[k] = { match: 0.0, prize: 0.0 } }
      submission_rows.each do |row|
        next unless row['Status'] == 'Curated'

        number = row['season number'] || seasons_meta[row['season']]&.dig(:number)
        next unless [4, 5].include?(number)

        awards[number][:match] += row['$ amount raised'].to_f
        awards[number][:prize] += row['prize unlocked usd'].to_f
      end
      existing = seasons.index_by { |season| season[:number] }
      awards.each do |number, extra|
        added = extra[:match] + extra[:prize]
        next unless added.positive?

        if (row = existing[number])
          row[:match] += extra[:match]
          row[:prize] += extra[:prize]
          row[:raised] = row[:sales].to_f + row[:venus].to_f + row[:match] + row[:prize]
        else
          meta = seasons_meta.values.find { |season| season[:number] == number }
          seasons << {
            number: number,
            title: meta&.dig(:title) || "Season #{number}",
            sales: 0.0,
            venus: 0.0,
            match: extra[:match],
            prize: extra[:prize],
            raised: added
          }
        end
      end
    end

    def curated_awards_by_project(season_id)
      awards = Hash.new { |h, k| h[k] = { match: 0.0, prize: 0.0 } }
      list(
        'projectsubmission',
        constraints: [
          { key: 'season', constraint_type: 'equals', value: season_id },
          { key: 'Status', constraint_type: 'equals', value: 'Curated' }
        ]
      ).each do |row|
        project_id = row['Project']
        next if project_id.blank?

        awards[project_id][:match] += row['$ amount raised'].to_f
        awards[project_id][:prize] += row['prize unlocked usd'].to_f
      end
      awards
    end

    def legacy_season_project_rows(season)
      number = season[:number]
      constraints = case number
                    when 4
                      [{ key: 'season 4 total raised ', constraint_type: 'greater than', value: 0 }]
                    when 5
                      [{ key: 'season 5 total sales', constraint_type: 'greater than', value: 0 }]
                    else
                      return []
                    end
      awards = curated_awards_by_project(season[:id])
      list('project', constraints: constraints).filter_map do |project|
        next if project['Hide'] || project['unPublished']

        name = project['Name'].to_s.strip
        next if name.blank?

        funding = legacy_season_funding(project, number)
        next unless funding

        extra = awards[project['_id']]
        if extra
          funding[:match] += extra[:match]
          funding[:prize] += extra[:prize]
          funding[:raised] = funding[:sales] + funding[:venus] + funding[:match] + funding[:prize]
        end
        next unless funding[:raised].to_f.positive?

        slug = project['Slug'].presence || project['_id']
        funding.merge(
          name: name,
          url: local_project_path(slug),
          creator: project["Lead Creator\t(text)"].to_s.strip.presence,
          logline: project['Logline'].presence
        )
      end
    end

    def apply_season_names(drives, seasons_meta)
      drives.each do |drive|
        meta = seasons_meta[drive[:season_id]]
        drive[:season_number] ||= meta&.dig(:number)
        drive[:season] = meta&.dig(:title) || (drive[:season_number] && "Season #{drive[:season_number]}")
      end
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
