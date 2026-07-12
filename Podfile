target 'LoopFollow' do
  use_frameworks!

  pod 'ShareClient', :git => 'https://github.com/loopandlearn/dexcom-share-client-swift.git', :branch => 'loopfollow'

end

post_install do |installer|
  # Set minimum deployment target for all pods to match the app (suppresses deprecation warnings)
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      if config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'].to_f < 16.6
        config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '16.6'
      end
    end
  end
end
