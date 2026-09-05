Pod::Spec.new do |s|
  s.name             = 'omm_scratch_audio'
  s.version          = '0.1.0'
  s.summary          = 'Native PCM output for single-deck DJ scratching.'
  s.description      = 'Bidirectional PCM cursor shared by normal and scratch playback handoff.'
  s.homepage         = 'https://github.com/example'
  s.license          = { :type => 'MIT' }
  s.author           = { 'omm' => 'dev@oh-my-media.local' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '16.0'
  s.swift_version = '5.9'
end
