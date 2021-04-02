require 'test_helper'
require 'SOLIDserver'
require 'smart_proxy_efficient_ip/main'
require 'smart_proxy_efficient_ip/const'

SIZE_TO_MASK = ::Proxy::DHCP::EfficientIp::SIZE_TO_MASK

class ProviderTest < Test::Unit::TestCase
  def setup
    @connection = ::SOLIDserver::SOLIDserver.new('10.10.10.10', 'username', 'password')
    @api = ::Proxy::DHCP::EfficientIp::Api.new(@connection)
    @provider = ::Proxy::DHCP::EfficientIp::Provider.new(@api, nil)
  end

  def test_find_subnet
    network_address = '192.168.45.0'
    subnet_params = { 'subnet_id' => '106', 'subnet_size' => '256' }

    @api.expects(:find_subnet).with(network_address).returns(subnet_params)

    result = @provider.find_subnet(network_address)

    assert_instance_of ::Proxy::DHCP::Subnet, result
    assert_equal result.network, network_address
    assert_equal result.netmask, ::Proxy::DHCP::EfficientIp::SIZE_TO_MASK[subnet_params['subnet_size'].to_i]
  end

  def test_find_subnets
    network_address = '192.168.45.0'
    subnets_params = [
      { 'subnet_id' => '106', 'start_hostaddr' => '192.168.84.0', 'subnet_size' => '256' },
      { 'subnet_id' => '125', 'start_hostaddr' => '192.168.88.0', 'subnet_size' => '128' },
    ]

    @api.expects(:subnets).returns(subnets_params)

    result = @provider.subnets
    assert_instance_of ::Proxy::DHCP::Subnet, result[0]
    assert_instance_of ::Proxy::DHCP::Subnet, result[1]
    assert_equal result[0].network, subnets_params[0]['start_hostaddr']
    assert_equal result[1].network, subnets_params[1]['start_hostaddr']
    assert_equal result[0].netmask, SIZE_TO_MASK[subnets_params[0]['subnet_size'].to_i]
    assert_equal result[1].netmask, SIZE_TO_MASK[subnets_params[1]['subnet_size'].to_i]
  end

  def test_all_hosts
    network_address = '192.168.75.0'
    subnet = { 'subnet_id' => '106', 'subnet_size' => '256' }
    hosts = [
      { 'name' => 'Rick', 'hostaddr' => '192.168.75.23', 'mac_addr' => '8a:9c:3e:c3:5a:6b' },
      { 'name' => 'Morty', 'hostaddr' => '192.168.75.67', 'mac_addr' => 'af:94:2d:6d:7e:7e' }
    ]


    @api.expects(:hosts).with(network_address).returns(hosts)
    @api.expects(:find_subnet).with(network_address).returns(subnet)

    result = @provider.all_hosts(network_address)

    assert_instance_of ::Proxy::DHCP::Reservation, result[0]
    assert_instance_of ::Proxy::DHCP::Reservation, result[1]
    assert_equal result[0].name, hosts[0]['name']
    assert_equal result[1].name, hosts[1]['name']
    assert_equal result[0].ip, hosts[0]['hostaddr']
    assert_equal result[1].ip, hosts[1]['hostaddr']
    assert_equal result[0].mac, hosts[0]['mac_addr']
    assert_equal result[1].mac, hosts[1]['mac_addr']
  end

  def test_all_leases
    network_address = '192.168.85.0'
    subnet = { 'subnet_id' => '106', 'subnet_size' => '256' }
    leases = [
      {
        'dhcplease_id' => '78',
        'dhcplease_name' => 'Nick',
        'dhcplease_addr' => '192.168.75.23',
        'dhcplease_mac_addr' => '8a:9c:3e:c3:5a:6b',
        'dhcplease_first_time' => '1617021896',
        'dhcplease_end_time' => '1617066741',
        'time_to_expire' => '54632'
      },
      {
        'dhcplease_id' => '31',
        'dhcplease_name' => 'Jack',
        'dhcplease_addr' => '192.168.75.67',
        'dhcplease_mac_addr' => 'af:94:2d:6d:7e:7e',
        'dhcplease_first_time' => '1617021396',
        'dhcplease_end_time' => '1617066421',
        'time_to_expire' => '631'
      }
    ]


    @api.expects(:leases).with(network_address).returns(leases)
    @api.expects(:find_subnet).with(network_address).returns(subnet)

    result = @provider.all_leases(network_address)

    assert_instance_of ::Proxy::DHCP::Lease, result[0]
    assert_instance_of ::Proxy::DHCP::Lease, result[1]
    assert_equal result[0].name, leases[0]['dhcplease_name']
    assert_equal result[1].name, leases[1]['dhcplease_name']
    assert_equal result[0].ip, leases[0]['dhcplease_addr']
    assert_equal result[1].ip, leases[1]['dhcplease_addr']
    assert_equal result[0].mac, leases[0]['dhcplease_mac_addr']
    assert_equal result[1].mac, leases[1]['dhcplease_mac_addr']
  end

  def test_unused_ip
    network_address = '192.168.85.0'
    free_ip = '192.168.85.64'
    start_ip = '192.168.85.12'
    end_ip = '192.168.85.112'
    server_response = { 'hostaddr' => free_ip }

    @api.expects(:find_free).with(network_address, start_ip, end_ip).returns(server_response)

    result = @provider.unused_ip(network_address, nil, start_ip, end_ip)

    assert_equal result, free_ip
  end

  def test_find_record
    network_address = '192.168.95.0'
    ip = '192.168.95.23'
    record_params = { 'hostaddr' => ip, 'mac_addr' => 'e1:2c:07:c1:46:7b', 'name' => 'First' }
    subnet_params = { 'subnet_id' => '577', 'subnet_size' => '256' }

    @api.expects(:find_subnet).with(network_address).returns(subnet_params)
    @api.expects(:find_record).with(ip).returns(record_params)

    result = @provider.find_record(network_address, ip)

    assert_instance_of Proxy::DHCP::Reservation, result
    assert_equal result.ip, record_params['hostaddr']
    assert_equal result.mac, record_params['mac_addr']
    assert_equal result.name, record_params['name']
  end
end
