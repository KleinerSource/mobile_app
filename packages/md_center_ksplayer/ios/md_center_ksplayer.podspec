Pod::Spec.new do |s|
  s.name             = 'md_center_ksplayer'
  s.version          = '0.1.0'
  s.summary          = 'KSPlayer engine bridge for md_center.'
  s.description      = 'Typed Flutter bridge around KSPlayer for md_center.'
  s.homepage         = 'https://github.com/KleinerSource/mobile_app'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'md_center' => 'dev@md-center.local' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.dependency 'Flutter'
  s.dependency 'KSPlayer'
  s.platform = :ios, '16.0'
  s.swift_version = '5.9'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
end
