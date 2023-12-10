require 'smart_proxy_efficient_ip/version'
require 'smart_proxy_efficient_ip/configuration'

module Proxy
  module DHCP
    module EfficientIp
      class Plugin < ::Proxy::Provider
        plugin :dhcp_efficient_ip, ::Proxy::DHCP::EfficientIp::VERSION

        capability 'dhcp_filename_ipv4'
        capability 'dhcp_filename_hostname'

        validate_presence :username, :password, :server_id, :address_type

        # Settings listed under default_settings are required.
        # An exception will be raised if they are initialized with nil values.
        # Settings not listed under default_settings are considered optional and by default have nil value.
        # default_settings :required_setting => 'default_value'

        requires :dhcp, '>= 2.1'

        # Verifies that a file exists and is readable.
        # Uninitialized optional settings will not trigger validation errors.
        # validate_readable :required_path, :optional_path

        load_classes ::Proxy::DHCP::EfficientIp::Configuration
        load_dependency_injection_wirings ::Proxy::DHCP::EfficientIp::Configuration
      end
    end
  end
end
