module EvalColors
  FALLBACK = '#646464'

  LABS = {
    'Anthropic' => '#d97757',
    'OpenAI' => '#10a37f',
    'xAI' => '#525252',
    'Google' => '#1a73e8',
    'Cursor' => '#6366f1',
    'Cognition' => '#2200ff',
    'Moonshot' => '#7c3aed',
    'Zhipu' => '#14b8a6',
    'DeepSeek' => '#4d6bfe',
    'MiniMax' => '#e5484d',
    'Thinking Machines' => '#e3a857',
    'Alibaba' => '#ff8800',
    'NVIDIA' => '#76b900',
    'Mistral' => '#fa500f',
    'Muse' => '#ec4899',
    'Antigravity' => '#eab308',
    'Opencode' => '#a855f7'
  }.freeze

  ALIASES = {
    'Claude Code' => 'Anthropic',
    'Codex' => 'OpenAI',
    'Grok Build' => 'xAI',
    'Gemini CLI' => 'Google',
    'Cursor CLI' => 'Cursor',
    'Devin Fusion CLI' => 'Cognition',
    'Kimi Code CLI' => 'Moonshot',
    'Muse Code' => 'Muse',
    'Antigravity SDK' => 'Antigravity',
    'Opencode' => 'Opencode'
  }.freeze

  MATCHERS = [
    [/\AClaude/i, 'Anthropic'],
    [/\AFable/i, 'Anthropic'],
    [/\AOpus/i, 'Anthropic'],
    [/\ASonnet/i, 'Anthropic'],
    [/\AGPT/i, 'OpenAI'],
    [/\AGrok/i, 'xAI'],
    [/\AGemini/i, 'Google'],
    [/\ASWE/i, 'Cognition'],
    [/\AKimi/i, 'Moonshot'],
    [/\AComposer/i, 'Cursor'],
    [/\AMuse/i, 'Muse'],
    [/\AGLM/i, 'Zhipu'],
    [/\ADeepSeek/i, 'DeepSeek'],
    [/\AMiniMax/i, 'MiniMax'],
    [/\AInkling/i, 'Thinking Machines'],
    [/\AQwen/i, 'Alibaba'],
    [/\ANemotron/i, 'NVIDIA'],
    [/\AMistral/i, 'Mistral']
  ].freeze

  class << self
    def lab_for(name)
      key = name.to_s.strip
      return if key == ''
      return key if LABS.key?(key)
      return ALIASES[key] if ALIASES[key]

      match = MATCHERS.find { |pattern, _lab| key.match?(pattern) }
      match ? match[1] : nil
    end

    def hex(name)
      LABS[lab_for(name)] || FALLBACK
    end

    def map_for(names)
      names.each_with_object({}) do |name, colors|
        next if name.to_s.strip == ''

        colors[name] = hex(name)
      end
    end
  end
end
