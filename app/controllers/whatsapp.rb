StephenReid::App.controller do
  get '/whatsapp' do
    halt 400 unless params[:'hub.verify_token'] == ENV['WHATSAPP_VERIFY_TOKEN']
    params[:'hub.challenge']
  end

  post '/whatsapp' do
    body = JSON.parse(request.body.read)
    message = body['entry'][0]['changes'][0]['value']['messages'][0]

    puts message.inspect

    if message['type'] == 'voice'
      media_id = message['voice']['id']
      voice_url = get_media_url(media_id)
      transcription = transcribe_audio(voice_url)
      send_whatsapp_message(message['from'], transcription)
    end

    status 200
  end

  private

  def get_media_url(media_id)
    token = ENV['WHATSAPP_ACCESS_TOKEN']
    phone_number_id = ENV['WHATSAPP_PHONE_NUMBER_ID']
    url = "https://graph.facebook.com/v21.0/#{phone_number_id}/media/#{media_id}"

    response = HTTP.auth("Bearer #{token}").get(url)
    data = JSON.parse(response.body)
    data['url']
  end

  def transcribe_audio(audio_url)
    client = OpenAI::Client.new(access_token: ENV['OPENAI_API_KEY'])
    response = client.audio.transcribe(
      parameters: {
        model: 'whisper-1',
        file: URI.open(audio_url)
      }
    )
    response.dig('text')
  end

  def send_whatsapp_message(to, message)
    token = ENV['WHATSAPP_ACCESS_TOKEN']
    phone_number_id = ENV['WHATSAPP_PHONE_NUMBER_ID']
    url = "https://graph.facebook.com/v21.0/#{phone_number_id}/messages"

    payload = {
      messaging_product: 'whatsapp',
      to: to,
      type: 'text',
      text: { body: message }
    }

    response = HTTP.auth("Bearer #{token}")
                   .post(url, json: payload)

    return if response.status.success?

    logger.error "Failed to send WhatsApp message: #{response.body}"
  end
end
