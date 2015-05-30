# Uncomment this line to define a global platform for your project
# platform :ios, "7.0"

target "ios-demo" do

pod 'libjingle_peerconnection'
pod 'TLKWebRTC', :git => 'https://github.com/evermeer/TLKWebRTC.git'  #'https://github.com/otalk/TLKWebRTC.git'
pod 'TLKSimpleWebRTC', :git => 'https://github.com/otalk/TLKSimpleWebRTC.git'

end

post_install do |installer_representation|
    installer_representation.project.targets.each do |target|
        target.build_configurations.each do |config|
            config.build_settings['ONLY_ACTIVE_ARCH'] = 'NO'
        end
    end
end