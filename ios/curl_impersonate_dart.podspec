Pod::Spec.new do |s|
  s.name             = 'curl_impersonate_dart'
  s.version          = '0.1.0'
  s.summary          = 'Flutter iOS plugin for libcurl-impersonate'
  s.description      = <<-DESC
Flutter iOS plugin wrapping libcurl-impersonate.
                       DESC
  s.homepage         = 'https://github.com/carter/curl_impersonate_dart'
  s.license          = { :type => 'MIT' }
  s.author           = { 'Carter' => 'carter@example.com' }

  # Fetch the framework during pod install
  s.prepare_command  = <<-CMD
    if [ ! -f "libcurl-impersonate.xcframework/ios-arm64/libcurl-impersonate.a" ]; then
      echo "Downloading libcurl-impersonate.xcframework..."
      rm -rf libcurl-impersonate.xcframework
      curl -L -o framework.tar.gz https://github.com/lexiforest/curl-impersonate/releases/download/v1.5.6/libcurl-impersonate-v1.5.6.ios-xcframework.tar.gz
      tar -xzf framework.tar.gz
      rm framework.tar.gz
    fi
  CMD

  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform         = :ios, '11.0'

  s.vendored_frameworks = 'libcurl-impersonate.xcframework'
  s.libraries = 'c++', 'iconv', 'icucore', 'z'
  
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
end
