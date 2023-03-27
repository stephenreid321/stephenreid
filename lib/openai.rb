OPENAI = Faraday.new(
  url: 'https://api.openai.com/v1',
  headers: { 'Content-Type': 'application/json', Authorization: "Bearer #{ENV['OPENAI_API_KEY']}" },
  request: { timeout: 300 }
)
