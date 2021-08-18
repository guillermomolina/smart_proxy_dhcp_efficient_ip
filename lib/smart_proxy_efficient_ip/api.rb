module Proxy
  module DHCP
    module EfficientIp
      class Api
        attr_reader :connection

        def initialize(connection, address_type)
          @connection = connection
          @address_type = address_type
        end

        def find_subnet(network_address)
          result = connection.ip_subnet_list(
            where: "start_hostaddr='#{network_address}' and is_terminal='1'",
            limit: 1
          )
          parse(result.body)&.first
        end

        def subnets
          result = connection.ip_subnet_list(
            where: "is_terminal='1' and start_hostaddr!='0.0.0.0'"
          )
          parse(result.body)
        end

        def find_free(network_address, start_ip, end_ip)
          subnet = find_subnet(network_address)

          result = connection.ip_address_find_free(
            subnet_id: subnet['subnet_id'],
            begin_addr: start_ip,
            end_addr: end_ip,
            max_find: 1
          )
          parse(result.body)&.first
        end

        def find_record(ip_or_mac)
          result = connection.ip_address_list(
            where: "type='ip' and (hostaddr='#{ip_or_mac}' or mac_addr='#{ip_or_mac}')",
            limit: 1
          )
          parse(result.body)&.first
        end

        def find_records(ip_or_mac)
          result = connection.ip_address_list(
            where: "type='ip' and (hostaddr='#{ip_or_mac}' or mac_addr='#{ip_or_mac}')",
          )
          parse(result.body)
        end

        def hosts(network_address)
          subnet = find_subnet(network_address)
          result = connection.ip_address_list(
            where: "subnet_id=#{subnet['subnet_id']} and dhcphost_id > 0"
          )
          parse(result.body)
        end

        def leases(network_address)
          # grab the subnet information where the leases exist
          subnet = find_subnet(network_address)

          #Perform gets based on address_type
          if address_type.eql? "dhcp"
            # DHCP IP Assignments
            leases = connection.ip_address_list(
              where: "subnet_id=#{subnet['subnet_id']} and dhcplease_id > 0"
            )
          elsif address_type.eql? "static"
            # Static IP Assignments
            leases = connection.ip_address_list(
            tags: "ip.dhcpstatic",
            where: "subnet_id=#{subnet['subnet_id']} and tag_ip_dhcpstatic='1'"
            )
          end

          if leases.code == 200
            lease_ids = parse(leases.body)
            lease_ids = parse(connection.ip_address_list(
              where: "subnet_id=#{subnet['subnet_id']} and dhcplease_id > 0"
            ).body).map { |r| r['dhcplease_id'] }

            result = connection.dhcp_lease_list(
              where: "dhcplease_id IN (#{lease_ids})"
            )
            parse(result.body)
          elsif leases.code == 204
            #no content returned
            return []
          end
        end

        def add_record(params)
          subnet = find_subnet(params['network'])

          connection.ip_address_add(
            site_name: subnet['site_name'],
            hostaddr: params['ip'],
            mac_addr: params['mac'],
            name: params['name'],
            ip_class_parameters: "dhcpstatic=1&dns_update=1&persistent_dns_rr=1&use_ipam_name=1"
          )
        end

        def delete_record(record)
          subnet = find_subnet(record.subnet.network)

          connection.ip_address_delete(
            hostaddr: record.ip,
            site_name: subnet['site_name'],
          )
        end

        def delete_records_by_ip(network_address, ip)
          subnet = find_subnet(network_address)

          connection.ip_address_delete(
            hostaddr: ip,
            site_name: subnet['site_name'],
          )
        end

        private

        def parse(response)
          response.empty? ? nil : JSON.parse(response)
        end
      end
    end
  end
end
