Pod::Spec.new do |s|
  s.name         = "webrtc-ios"
  s.version      = "5858"
  s.summary      = "iOS compiled WebRTC libraries"
  s.homepage     = "https://github.com/steamclock/webrtc-ios"
  s.license      = { :type => "OTHER", :file => "LICENSE" }
  s.author       = { "&yet" => "contact@andyet.com" }
  s.platform     = :ios, '7.0'
  s.source       = { :git => "https://github.com/otalk/webrtc-ios.git", :tag => s.version.to_s }
  s.source_files = "include/**/*.h"
  s.vendored_libraries = "lib/*.a"
  s.requires_arc = false
  s.library = 'sqlite3', 'stdc++'
  s.framework = 'AVFoundation', 'AudioToolbox', 'CoreMedia'
  s.xcconfig     = {
    'OTHER_LDFLAGS'  => '-stdlib=libstdc++',
	'ARCHS' => 'armv7',
	'ONLY_ACTIVE_ARCH' => 'NO'
  }
end
