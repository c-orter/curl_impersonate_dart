Pod::Spec.new do |s|
  s.name             = 'curl_impersonate_dart'
  s.version          = '0.2.0'
  s.summary          = 'Flutter iOS plugin for libcurl-impersonate'
  s.description      = <<-DESC
Flutter iOS plugin wrapping libcurl-impersonate.
                       DESC
  s.homepage         = 'https://github.com/carter/curl_impersonate_dart'
  s.license          = { :type => 'MIT' }
  s.author           = { 'Carter' => 'carter@example.com' }

  # Fetch the framework during pod install
  # NOTE: keep `v2.2.3` in sync with ext.curlImpersonateVersion in android/build.gradle.
  s.prepare_command  = <<-CMD
    if [ ! -f "libcurl-impersonate.xcframework/ios-arm64/libcurl-impersonate.a" ]; then
      echo "Downloading libcurl-impersonate.xcframework..."
      rm -rf libcurl-impersonate.xcframework
      curl -fL -o framework.tar.gz https://github.com/lexiforest/curl-impersonate/releases/download/v2.2.3/libcurl-impersonate-v2.2.3.ios-xcframework.tar.gz
      tar -xzf framework.tar.gz
      rm framework.tar.gz
    fi
  CMD

  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.dependency 'Flutter'
  # Upstream builds the ios slices with -miphoneos-version-min=13.0
  # (see .github/workflows/build.yml, ios_min_version). Declaring a lower
  # target here than the binary was compiled against will not link.
  s.platform         = :ios, '13.0'

  s.vendored_frameworks = 'libcurl-impersonate.xcframework'
  s.libraries = 'c++', 'iconv', 'icucore', 'z'
  
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
end
