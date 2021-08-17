require 'dhcp_common/server'
require 'smart_proxy_efficient_ip/const'
require 'smart_proxy_efficient_ip/api'

module Proxy
  module DHCP
    module EfficientIp
      class Provider < ::Proxy::DHCP::Server
        alias_method :find_record_by_mac, :find_record
        alias_method :find_record_by_ip, :find_record

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
          logger.debug("Searching first unused ip from:#{from_ip_address} to:#{to_ip_address}")

          free_ip =  api.find_free(network_address, from_ip_address, to_ip_address)
          free_ip['hostaddr'] if free_ip
        end

        def find_record(subnet_address, ip_or_mac_address)
          logger.debug("Finding record for subnet:#{subnet_address} and address:#{ip_or_mac_address}")

          subnet = find_subnet(subnet_address)
          record = api.find_record(ip_or_mac_address)

          record ? build_reservation(subnet, record) : nil
        end

        def find_records_by_ip(subnet_address, ip_or_mac)
          logger.debug("Finding records by address: #{ip_or_mac}")

          records = api.find_records(ip_or_mac)
          return [] if records.empty?
          subnet = find_subnet(subnet_address)

          #records.filter_map do |record|
          matching_record = records.select{|record|}
          record_result   = matching_record.map{|record|}
            reserv = build_reservation(subnet, record_result)
            reserv unless reserv.nil?
          #end
        end

        def add_record(params)
          logger.debug("Adding record with: #{params.to_s}")
          api.add_record(params)
        end

        def del_record(record)
          logger.debug("Deleting record: #{record.to_s}")
          api.delete_record(record)
        end

        def del_record_by_ip(subnet_address, ip)
          logger.debug("Deleting record: #{ip}")
          api.delete_record_by_ip(subnet_address, ip)
        end

        private

        attr_reader :api, :managed_subnets

        def build_reservation(subnet, record)
          return nil if record.empty? || record['hostaddr'].empty? || record['mac_addr'].empty?

          opts = { hostname: record['name'] }
          Proxy::DHCP::Reservation.new(
            record['name'], record['hostaddr'], record['mac_addr'], subnet, opts
          )
        end
      end
    end
  end
end
