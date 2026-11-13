require "json"

package = JSON.parse(File.read(File.join(__dir__, "package.json")))

Pod::Spec.new do |s|
  s.name         = "RNEmojiPicker"
  s.version      = package["version"]
  s.summary      = package["description"]
  s.homepage     = package["homepage"]
  s.license      = package["license"]
  s.authors      = package["author"]

  s.platforms    = { :ios => min_ios_version_supported }
  s.source       = { :git => "https://github.com/27AppStudio/react-native-emoji-picker.git", :tag => "v#{s.version}" }

  s.source_files = "ios/**/*.{h,m,mm,swift,cpp}"
  s.private_header_files = "ios/**/*.h"
  s.swift_version = "5.9"
  s.resource_bundles = { "RNEmojiPicker" => ["ios/Resources/*.json"] }

  install_modules_dependencies(s)
end
