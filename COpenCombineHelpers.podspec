Pod::Spec.new do |spec|
  spec.name          = "COpenCombineHelpers"
  spec.version       = "0.5.0"
  spec.summary       = "C++ Helpers for OpenCombine"

  spec.description   = <<-DESC
  C++ helpers necessary for the implementation of OpenCombine
  DESC

  spec.homepage      = "https://github.com/broadwaylamb/OpenCombine/"
  spec.license       = "MIT"

  spec.authors       = { "Sergej Jaskiewicz" => "jaskiewiczs@icloud.com" }
  spec.source        = { :git => "https://github.com/broadwaylamb/OpenCombine.git", :tag => "#{spec.version}" }

  spec.osx.deployment_target     = "10.10"
  spec.ios.deployment_target     = "8.0"
  spec.watchos.deployment_target = "2.0"
  spec.tvos.deployment_target    = "9.0"

  spec.header_mappings_dir       = "Sources/COpenCombineHelpers/include"
  spec.source_files              = "Sources/COpenCombineHelpers/**/*.{cpp,h}"
  spec.libraries                 = "c++"
  
  spec.pod_target_xcconfig = {
    "DEFINES_MODULE" => "YES"
  }
end