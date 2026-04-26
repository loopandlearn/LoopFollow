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
end
