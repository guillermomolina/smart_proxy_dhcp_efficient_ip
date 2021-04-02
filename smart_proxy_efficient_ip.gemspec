require File.expand_path('../lib/smart_proxy_efficient_ip/version', __FILE__)
require 'date'

Gem::Specification.new do |s|
  s.name        = 'smart_proxy_efficient_ip'
  s.version     = Proxy::DHCP::EfficientIp::VERSION
  s.date        = Date.today.to_s
  s.license     = 'GPL-3.0'
  s.authors     = ['Michal Olejniczak']
  s.email       = ['michal.olejniczak@ironin.pl']

  s.homepage    = 'https://gitlab.ironin.it/efficient-ip/smart-proxy-dhcp'
  s.summary     = "Smart proxy plugin for EfficientIP"
  s.description = "Plugin for integration Foreman's smart proxy with EfficientIP"

  s.files       = Dir['{config,lib,bundler.d}/**/*'] + ['README.md', 'LICENSE']
  s.test_files  = Dir['test/**/*']

  s.add_runtime_dependency('SOLIDserver', '~> 0.0.11')

  s.add_development_dependency('rake', '~> 13.0')
  s.add_development_dependency('mocha', '~> 1.11')
  s.add_development_dependency('test-unit', '~> 3.4')
end
