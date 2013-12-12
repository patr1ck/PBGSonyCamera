Pod::Spec.new do |s|
  s.name         = "PBGSonyCamera"
  s.version      = "1.0.0"
  s.summary      = "Provides an Objective-C interface to Sony Smart Remote Control-capable cameras."
  s.description  = <<-DESC
                   This pod provides an interface to Sony cameras that are capable of
				   running the "Smart Remote Control" app. This includes, but is not
				   limited to the NEX-5R/T, NEX-6, A7/A7R, etc.
				   
				   It does not provide a full API compatibility, but it does a few
				   rudimentary functions including liveview and can be easily expanded.
                   DESC
  s.homepage     = "http://github.com/patr1ck/PBGSonyCamera"
  s.author       = { "Patrick B. Gibson" => "patrick@fadeover.org" }
  s.license      = { :type => 'MIT', :file => 'LICENSE' }
  s.ios.deployment_target = '6.0'
  s.osx.deployment_target = '10.8'
  s.source       = { :git => "http://github.com/patr1ck/PBGSonyCamera.git", :tag => "1.0.0" }
  s.source_files  = 'Classes', 'Classes/**/*.{h,m}'
  s.exclude_files = 'Classes/Exclude'
  s.public_header_files = 'Classes/**/*.h'
  s.dependency 'AFNetworking', '~> 2.0.3'
  s.dependency 'CocoaAsyncSocket', '~> 7.3.2'
  s.requires_arc = true
end
