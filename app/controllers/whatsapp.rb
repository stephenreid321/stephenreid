StephenReid::App.controller do
  get '/whatsapp' do
    halt 400 unless params[:'hub.verify_token'] == ENV['WHATSAPP_VERIFY_TOKEN']
    params[:'hub.challenge']
  end

  post '/whatsapp' do
    body = JSON.parse(request.body.read)
    message = body['entry'][0]['changes'][0]['value']['messages'][0]

    token = ENV['WHATSAPP_ACCESS_TOKEN']
    phone_number_id = ENV['WHATSAPP_PHONE_NUMBER_ID']

    puts message.inspect

    if message['type'] == 'audio'
      media_id = message['audio']['id']

      # get the media url
      url = "https://graph.facebook.com/v21.0/#{media_id}"
      response = HTTP.auth("Bearer #{token}").get(url)
      data = JSON.parse(response.body)
      url = data['url']
      puts puts "media url: #{url}"

      # download the media
      response = HTTP.auth("Bearer #{token}").get(url)
      puts 'saving media to temp file'
      temp_file = Tempfile.new(['whatsapp_media', File.extname(url)])
      temp_file.binmode
      temp_file.write(response.body)
      temp_file.rewind
      path = temp_file.path

      # transcribe the audio
      client = OpenAI::Client.new(access_token: ENV['OPENAI_API_KEY'])
      response = client.audio.transcribe(
        parameters: {
          model: 'whisper-1',
          file: File.open(path)
        }
      )
      text = response.dig('text')
      puts text

      # send the transcription to the user
      url = "https://graph.facebook.com/v21.0/#{phone_number_id}/messages"
      to = message['from']
      payload = {
        messaging_product: 'whatsapp',
        to: to,
        type: 'text',
        text: { body: text }
      }
      HTTP.auth("Bearer #{token}")
          .post(url, json: payload)

    end

    200
  end
end
