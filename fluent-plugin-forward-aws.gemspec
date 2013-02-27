# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

Gem::Specification.new do |gem|
  gem.name          = "fluent-plugin-forward-aws"
  gem.version       = "0.1.0"
  gem.authors       = ["Tomohisa Ota"]
  gem.email         = ["tomohisa.ota+github@gmail.com"]
  gem.description   = "Fluentd Forward Plugin using Amazon Web Service"
  gem.summary       = gem.description
  gem.homepage      = ""

  gem.files         = `git ls-files`.split($/)
  gem.files.reject! { |fn| fn.include? "doc/" }
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.require_paths = ["lib"]

  gem.add_runtime_dependency "fluentd"
  gem.add_runtime_dependency "aws-sdk", "~> 1.8.2"
end
