target 'LoopFollow' do
  use_frameworks!

  pod 'Charts'
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

  # Patch Charts Transformer to avoid "CGAffineTransformInvert: singular matrix"
  # warnings when chart views have zero dimensions (before layout).
  transformer = 'Pods/Charts/Source/Charts/Utils/Transformer.swift'
  if File.exist?(transformer)
    code = File.read(transformer)
    original = 'return valueToPixelMatrix.inverted()'
    patched = <<~SWIFT.chomp
      let matrix = valueToPixelMatrix
            guard matrix.a * matrix.d - matrix.b * matrix.c != 0 else {
                return .identity
            }
            return matrix.inverted()
    SWIFT
    if code.include?(original)
      File.write(transformer, code.sub(original, patched))
    end
  end

  # Inject a privacy manifest into the Charts framework (ITMS-91061).
  # Charts 4.1.0 ships no PrivacyInfo.xcprivacy; it collects no data, performs
  # no tracking, and uses no required-reason APIs, so this is a negative
  # declaration. Re-applied here because `pod install` regenerates the project.
  charts_manifest = <<~XML
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0">
    <dict>
    \t<key>NSPrivacyTracking</key>
    \t<false/>
    \t<key>NSPrivacyTrackingDomains</key>
    \t<array/>
    \t<key>NSPrivacyCollectedDataTypes</key>
    \t<array/>
    \t<key>NSPrivacyAccessedAPITypes</key>
    \t<array/>
    </dict>
    </plist>
  XML

  manifest_path = installer.sandbox.root + 'Charts/PrivacyInfo.xcprivacy'
  File.write(manifest_path, charts_manifest)

  charts_target = installer.pods_project.targets.find { |t| t.name == 'Charts' }
  if charts_target
    file_ref = installer.pods_project.new_file(manifest_path.to_s)
    already_added = charts_target.resources_build_phase.files_references.include?(file_ref)
    charts_target.resources_build_phase.add_file_reference(file_ref) unless already_added
    installer.pods_project.save
  end
end
