Pod::Spec.new do |spec|
  spec.name          = "OpenCombineDispatch"
  spec.version       = "0.5.0"
  spec.summary       = "OpenCombine Dispatching"

  spec.description   = <<-DESC
  Extends `DispatchQueue` with new methods and nested types.
  DESC

  spec.homepage      = "https://github.com/broadwaylamb/OpenCombine/"
  spec.license       = "MIT"

  spec.authors       = { "Sergej Jaskiewicz" => "jaskiewiczs@icloud.com" }
  spec.source        = { :git => "https://github.com/broadwaylamb/OpenCombine.git", :tag => "#{spec.version}" }

  spec.swift_version = "5.0"

  spec.osx.deployment_target     = "10.10"
  spec.ios.deployment_target     = "8.0"
  spec.watchos.deployment_target = "2.0"
  spec.tvos.deployment_target    = "9.0"

  spec.source_files = "Sources/OpenCombineDispatch/**/*.swift"
  spec.dependency     "OpenCombine"
end