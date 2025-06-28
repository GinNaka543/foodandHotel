# Uncomment this line to define a global platform for your project
platform :ios, '18.5'

# CocoaPods analytics sends network stats synchronously affecting flutter build latency.
ENV['COCOAPODS_DISABLE_STATS'] = 'true'

target 'HappinessGameSwift' do
  use_frameworks!

  # Firebase
  pod 'Firebase/Core'
  pod 'Firebase/Auth'
  pod 'Firebase/Firestore'
  pod 'Firebase/Storage'
  
  # Image and Video handling
  pod 'SDWebImage'
  
  # UI Components
  pod 'SnapKit'
  
  target 'HappinessGameSwiftTests' do
    inherit! :search_paths
  end

  target 'HappinessGameSwiftUITests' do
  end
end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    flutter_additional_ios_build_settings(target)
    target.build_configurations.each do |config|
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '18.5'
      # Workaround for Xcode 16 beta build error "unsupported option '-G'"
      config.build_settings['GCC_GENERATE_DEBUGGING_SYMBOLS'] = 'NO'
      # Additional workarounds for Xcode 16
      config.build_settings['CLANG_WARN_QUOTED_INCLUDE_IN_FRAMEWORK_HEADER'] = 'NO'
      config.build_settings['DEAD_CODE_STRIPPING'] = 'YES'
      config.build_settings['ENABLE_BITCODE'] = 'NO'
      # Additional Xcode 16.4 specific fixes
      config.build_settings['DEBUG_INFORMATION_FORMAT'] = 'dwarf'
      config.build_settings['STRIP_SWIFT_SYMBOLS'] = 'YES'
      config.build_settings['STRIP_BITCODE_FROM_COPIED_FILES'] = 'YES'
      config.build_settings['HIDE_BITCODE_SYMBOLS'] = 'YES'
      config.build_settings['SEPARATE_SYMBOL_EDIT'] = 'NO'
      config.build_settings['GCC_SYMBOLS_PRIVATE_EXTERN'] = 'YES'
    end
  end
end 