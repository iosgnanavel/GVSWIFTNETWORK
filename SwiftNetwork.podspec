Pod::Spec.new do |s|
  s.name         = 'SwiftNetwork'
  s.version      = '0.0.1'
  s.summary      = 'SwiftNetwork is swift network api calls'
  s.homepage     = 'https://developers.apple.com'
  s.license      = 'MIT'
  s.author       = { 'iosgnanavel' => 'iosgnanavel@gmail.com' }
  s.source       = { :git => 'https://github.com/iosgnanavel/SwiftNetwork.git', :tag => s.version }

  s.source_files = 'SwiftNetwork/Networking/**/*'

  s.swift_version = '5.0'
  s.ios.deployment_target = '11.0'
  s.ios.frameworks = 'UIKit', 'MapKit', 'Foundation'
  s.dependency       'Alamofire', '~> 5.4.3'
end
