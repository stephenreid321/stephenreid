StephenReid::App.controller do
  post '/talk', provides: :json do
    @title = 'Talk'
    openai_response = OPENAI.post('chat/completions') do |req|
      req.body = { model: 'gpt-4', messages: [{ role: 'user', content: (audio_prompt + params[:messages]).join("\n\n") }] }.to_json
    end
    content = JSON.parse(openai_response.body)['choices'][0]['message']['content']
    content = content.split('Stephen: ').last
    content = content.split('Me: ').last
    content = content.gsub(/^\.+/, '').strip

    elevenlabs_response = ELEVENLABS.post("text-to-speech/#{ENV['ELEVENLABS_VOICE_ID']}") do |req|
      req.body = {
        text: content,
        voice_settings: {
          stability: 0,
          similarity_boost: 0
        }
      }.to_json
    end

    {
      text: content,
      audio: Base64.encode64(elevenlabs_response.body)
    }.to_json
  end

  get '/talk' do
    erb :talk
  end

  get '/talk/prompt' do
    (audio_prompt + ["Friend: Hi there, how's it going?", 'Stephen: Good thanks!']).join("\n\n").gsub("\n", '<br>')
  end
end
