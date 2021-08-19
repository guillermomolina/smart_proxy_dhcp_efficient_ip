module Proxy
  module DHCP
    module EfficientIp
      class Configuration
        def load_classes
          require 'SOLIDserver'
          require 'smart_proxy_efficient_ip/api'
          require 'smart_proxy_efficient_ip/main'
        end

        def load_dependency_injection_wirings(container_instance, settings)
          container_instance.dependency :connection, (lambda do
            ::SOLIDserver::SOLIDserver.new(
              settings[:server_id],
              settings[:username],
              settings[:password]
            )
          end)

          container_instance.dependency :api, (lambda do
            ::Proxy::DHCP::EfficientIp::Api.new(
              container_instance.get_dependency(:connection),
              settings[:address_type]
            )
          end)

          container_instance.dependency :dhcp_provider, (lambda do
            ::Proxy::DHCP::EfficientIp::Provider.new(
              container_instance.get_dependency(:api),
              settings[:subnets]
            )
          end)
        end
      end
    end
  end
end
