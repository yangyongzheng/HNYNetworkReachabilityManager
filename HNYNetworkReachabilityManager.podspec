#
# Be sure to run `pod lib lint HNYNetworkReachabilityManager.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name = 'HNYNetworkReachabilityManager'
  s.version = '1.0.0'
  s.summary = '网络可达性监听管理器'
  s.homepage = 'https://github.com/yangyongzheng/HNYNetworkReachabilityManager'
  s.license = { :type => 'MIT', :file => 'LICENSE' }
  s.authors = {
    'yangyongzheng' => 'youngyongzheng@qq.com'
  }
  s.source = {
    :git => 'https://github.com/yangyongzheng/HNYNetworkReachabilityManager.git',
    :tag => s.version.to_s
  }
  
  s.platform = :ios, '9.0'
  s.ios.deployment_target = '9.0'
  s.requires_arc = true
  
  s.source_files = 'Source/*.{h,m}'
  s.public_header_files = 'Source/*.h'
  
  s.ios.framework = 'SystemConfiguration'
end
