require 'dhcp_common/server'
require 'smart_proxy_efficient_ip/const'
require 'smart_proxy_efficient_ip/api'

module Proxy
  module DHCP
    module EfficientIp
      class Provider < ::Proxy::DHCP::Server

        def initialize(api, managed_subnets)
          @managed_subnets = managed_subnets
          @api = api
          super('efficient_ip', managed_subnets, nil)
        end

        def find_subnet(network_address)
          logger.debug("Finding subnet #{network_address}")
          subnet = api.find_subnet(network_address)
          return nil unless subnet

          netmask = SIZE_TO_MASK[subnet['subnet_size'].to_i]
          ::Proxy::DHCP::Subnet.new(network_address, netmask)
        end

        def get_subnet(network_address)
          find_subnet(network_address) ||
            raise(Proxy::DHCP::SubnetNotFound.new("No such subnet: %s" % [network_address]))
        end

        def subnets
          result = api.subnets

         # result.filter_map do |subnet|
          matching_subnet = result.select{|subnet|}
          subnet_result   = matching_subnet.map{|subnet|}
          address = subnet_result['start_hostaddr']
          subnet_size = subnet_result['subnet_size'].to_i
          netmask = SIZE_TO_MASK[subnet_size]

          if subnet_size >= 1 && managed_subnet?("#{address}/#{netmask}")
            Proxy::DHCP::Subnet.new(address, netmask)
          end
        end

        def all_hosts(network_address)
          logger.debug("Fetching hosts for #{network_address}")
          hosts = api.hosts(network_address)
          return [] unless hosts

          subnet = find_subnet(network_address)
          hosts.map do |host|
            Proxy::DHCP::Reservation.new(
              host['name'], host['hostaddr'], host['mac_addr'], subnet
            )
          end
        end

        def all_leases(network_address)
          logger.debug("Fetching leases for #{network_address}")
          leases = api.leases(network_address)
          return [] unless leases

          subnet = find_subnet(network_address)
          leases.map do |lease|
            Proxy::DHCP::Lease.new(
              lease['dhcplease_name'],
              lease['dhcplease_addr'],
              lease['dhcplease_mac_addr'].split(':')[1..6].join(':'),
              subnet,
              DateTime.strptime(lease['dhcplease_first_time'], '%s'),
              DateTime.strptime(lease['dhcplease_end_time'], '%s'),
              lease['time_to_expire'].to_i > 0 ? 'active' : 'free'
            )
          end
        end

        def unused_ip(network_address, _, from_ip_address, to_ip_address)
          logger.debug("DEBUG :: invoking unused_ip")
          logger.debug("Searching first unused ip from:#{from_ip_address} to:#{to_ip_address}")

          free_ip =  api.find_free(network_address, from_ip_address, to_ip_address)
          free_ip['hostaddr'] if free_ip
        end

        def find_record(subnet_address, ip_or_mac_address)
          logger.debug("DEBUG :: invoking find_record")
          logger.debug("Finding record for subnet:#{subnet_address} and address:#{ip_or_mac_address}")

          subnet = find_subnet(subnet_address)
          record = api.find_record(ip_or_mac_address)

          record ? build_reservation(subnet, record) : nil
        end

        def find_record_by_ip(subnet_address, ip_address)
          logger.debug("DEBUG :: invoking find_record_by_ip")
          logger.debug("Finding record for subnet:#{subnet_address} and address:#{ip_or_mac_address}")

          subnet = find_subnet(subnet_address)
          record = api.find_record(ip_address)

          if !record.nil
            opts = { "hostname" => record['name'] }

            reserv = Proxy::DHCP::Reservation.new(
              record['name'],
              record['hostaddr'],
              record['mac_addr'],
              subnet,
              opts
            )

            some_val = reserv.to_json()
            logger.debug("DEBUG :: #{some_val}")
            return reserv
            #build_reservation(subnet, record)
          end
        end

        def find_record_by_mac(subnet_address, mac_address)
          logger.debug("DEBUG :: invoking find_record_by_mac")
          logger.debug("Finding record for subnet:#{subnet_address} and mac address:#{mac_address}")

          subnet = find_subnet(subnet_address)
          record = api.find_record(mac_address)
          #record ? build_reservation(subnet, record) : nil

          if !record.nil?
            opts = { "hostname" => record['name'] }

            reserv = Proxy::DHCP::Reservation.new(
              record['name'],
              record['hostaddr'],
              record['mac_addr'],
              subnet,
              opts
            )

            some_val = reserv.to_json()
            logger.debug("DEBUG :: Calling to_json()  #{some_val}")
            return reserv
            #build_reservation(subnet, record)
          end
        end

        def find_records_by_ip(subnet_address, ip_address)
          logger.debug("DEBUG :: invoking find_records_by_ip")
          logger.debug("Finding records by address: #{ip_address}")

          records = api.find_records(ip_address)
          logger.debug("DEBUG :: Returning records #{records}")
          if records.nil?
            return []
          end

          subnet = find_subnet(subnet_address)

          record = records.find{|r| r['hostaddr'].eql?(ip_address)}
          #logger.debug("#{record}")
          logger.debug("Building reservation with record: #{record['hostaddr']}")

          reserv = build_reservation(subnet, record)

          some_val = reserv.to_json()
          logger.debug("DEBUG :: #{some_val}")
          logger.debug("DEBUG Reservation created: #{reserv}")
          reserv unless reserv.nil?
        end

        def add_record(params)
          logger.debug("Adding record with: #{params.to_s}")
          api.add_record(params)

          dhcp_exists = 0
          #Wait for DHCP server to update
          loop do
            static = api.get_dhcp_static(params['ip'])
            break if static.nil?
              logger.debug("DHCP Server response for #{params['ip']} is Delayed Create :: #{static[0]['delayed_create_time']} ")
              static.each do |ipaddr|
                if ipaddr['delayed_create_time'].to_i == 0
                  dhcp_exists = 1
                end
              end
            break if dhcp_exists == 1
            sleep 10
          end
        end

        def del_record(record)
          logger.debug("Deleting record: #{record.to_s}")
          api.delete_record(record)
        end

        def del_records_by_ip(subnet_address, ip)
          logger.debug("Deleting record: #{ip}")
          api.delete_records_by_ip(subnet_address, ip)
        end

        def del_record_by_mac(network_address, mac)
          logger.debug("Deleting record with mac address: #{mac}")
          subnet = get_subnet(network_address)
          record = api.find_record(mac)

          if !record.nil? and !subnet.nil?
            api.delete_record(record["site_name"], record["hostaddr"])
          end
        end

        private

        attr_reader :api, :managed_subnets

        def build_reservation(subnet, record)
          return nil if record.empty? || record['hostaddr'].empty? || record['mac_addr'].empty?

          opts = { "hostname" => record['name'] }
          Proxy::DHCP::Reservation.new(
            record['name'], record['hostaddr'], record['mac_addr'], subnet, opts
          )
        end

      end
    end
  end
end
