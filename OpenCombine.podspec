Pod::Spec.new do |spec|
  spec.name         = "OpenCombine"
  spec.version      = "0.0.1"
  spec.summary      = "Open source implementation of Apple's Combine framework for processing values over time."

  spec.description  = <<-DESC
  Open source implementation of Apple's Combine framework for processing values over time.
  DESC

  spec.homepage     = "https://github.com/broadwaylamb/OpenCombine/"

  spec.license      = "Apache 2.0"

  spec.author       = "Apple"
  spec.source       = { :git => "https://github.com/broadwaylamb/OpenCombine", :tag => "#{spec.version}" }

  spec.swift_version = '5.0'

  spec.osx.deployment_target     = '10.10'
  spec.ios.deployment_target     = '12.0'

  spec.source_files = "Sources/**/*.swift"
  spec.test_spec do |test_spec|
    test_spec.osx.deployment_target  = '10.10'
    test_spec.ios.deployment_target  = '12.0'

    test_spec.source_files = "Tests/**/*.swift"
  end
end