Pod::Spec.new do |s|
  s.name             = 'md_center_avplayer'
  s.version          = '0.1.0'
  s.summary          = 'AVPlayer engine for md_center.'
  s.description      = 'Typed Flutter bridge around AVPlayer for md_center.'
  s.homepage         = 'https://github.com/md-center/md-center'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'md_center' => 'dev@md-center.local' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '16.0'
  s.swift_version = '5.9'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }

  s.test_spec 'Tests' do |test_spec|
    test_spec.source_files = 'Tests/**/*'
  end
end
