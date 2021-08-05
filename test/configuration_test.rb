require 'test_helper'
require 'SOLIDserver'
require 'dhcp_common/dhcp_common'
require 'smart_proxy_efficient_ip/api'
require 'smart_proxy_efficient_ip/main'
require 'smart_proxy_efficient_ip/configuration'

class ConfigurationTest < Test::Unit::TestCase
  def setup
    @settings = {
      username: 'user',
      password: 'password',
      server_ip: '10.10.10.10'
    }
    @container = ::Proxy::DependencyInjection::Container.new
    Proxy::DHCP::EfficientIp::Configuration.new.load_dependency_injection_wirings(@container, @settings)
  end

  def test_connection
    connection = @container.get_dependency(:connection)

    assert_instance_of ::SOLIDserver::SOLIDserver, connection
  end

  def test_api
    api = @container.get_dependency(:api)

    assert_instance_of ::Proxy::DHCP::EfficientIp::Api, api
  end

  def test_provider
    provider = @container.get_dependency(:dhcp_provider)

    assert_instance_of ::Proxy::DHCP::EfficientIp::Provider, provider
  end
end


