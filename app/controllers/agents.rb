StephenReid::App.controller do
  # Extract a JSON array value that follows `key` (e.g. `"rows":`), skipping string contents
  # so `]` inside strings does not terminate early.
  extract_json_array = lambda do |body, key|
    i = body.index(key)
    return nil unless i

    start = i + key.bytesize
    start += 1 while start < body.length && body[start] =~ /\s/
    return nil unless body[start] == '['

    depth = 0
    in_string = false
    escape = false
    pos = start
    while pos < body.length
      c = body[pos]
      if escape
        escape = false
        pos += 1
        next
      end
      if in_string
        if c == '\\'
          escape = true
        elsif c == '"'
          in_string = false
        end
        pos += 1
        next
      end
      case c
      when '"'
        in_string = true
      when '['
        depth += 1
      when ']'
        depth -= 1
        return body[start..pos] if depth.zero?
      end
      pos += 1
    end
    nil
  end

  get '/agents', cache: true do
    @container_class = 'container-fluid'
    @stylesheet = 'light'
    @title = 'Coding agents'

    response = Faraday.get('https://artificialanalysis.ai/agents/coding-agents') do |req|
      req.headers['RSC'] = '1'
    end
    body = response.body.force_encoding('UTF-8').scrub

    rows_json = extract_json_array.call(body, '"rows":')
    @agent_rows =
      begin
        rows = rows_json ? JSON.parse(rows_json) : []
        rows.each do |row|
          row['components_by_dataset'] = (row['componentScores'] || []).each_with_object({}) do |c, h|
            h[c['datasetIndexName']] = c
          end
        end
        rows.sort_by { |r| -(r['indexScore'] || 0).to_f }
      rescue JSON::ParserError
        []
      end

    erb :agents
  end
end
