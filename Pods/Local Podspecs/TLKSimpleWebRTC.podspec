Pod::Spec.new do |s|
  s.name         = "TLKSimpleWebRTC"
  s.version      = "0.0.3"
  s.summary      = "A iOS interface to a SimpleWebRTC based signalling server using Socket.io"
  s.homepage     = "https://github.com/otalk/TLKSimpleWebRTC"
  s.license      = { :type => "MIT", :file => "LICENSE" }
  s.author       = { "&yet" => "contact@andyet.com" }
  s.platform     = :ios, '7.0'
  s.source       = { :git => "https://github.com/otalk/TLKSimpleWebRTC.git", :tag => s.version.to_s }
  s.source_files = "*.{h,m}"
  s.requires_arc = true
  s.dependency 'AZSocketIO', '0.0.5'
end
