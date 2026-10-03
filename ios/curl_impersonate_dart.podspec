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

  # Fetch the framework during pod install.
  # NOTE: keep `v2.2.2` in sync with ext.curlImpersonateVersion in
  # android/build.gradle. 2.2.2 rather than 2.2.3 because 2.2.3 links c-ares,
  # whose Android name resolution cannot read net.dns* as an untrusted app.
  # See the comment there before bumping.
  #
  # The .curl-impersonate-version stamp is what makes this a versioned cache.
  # Existence of the extracted framework is not: CocoaPods reuses an existing
  # libcurl-impersonate.xcframework across installs, so bumping the version
  # alone would silently keep serving the previous release's binary -- the same
  # class of bug already fixed on the Android side.
  s.prepare_command  = <<-CMD
    set -e
    STAMP="libcurl-impersonate.xcframework/.curl-impersonate-version"
    if [ ! -f "$STAMP" ] || [ "$(cat "$STAMP" 2>/dev/null)" != "v2.2.2" ]; then
      echo "Downloading libcurl-impersonate.xcframework v2.2.2..."
      rm -rf libcurl-impersonate.xcframework
      curl -fL -o framework.tar.gz https://github.com/lexiforest/curl-impersonate/releases/download/v2.2.2/libcurl-impersonate-v2.2.2.ios-xcframework.tar.gz
      tar -xzf framework.tar.gz
      rm framework.tar.gz
      echo "v2.2.2" > "$STAMP"
    else
      echo "libcurl-impersonate v2.2.2 already present, skipping download."
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
