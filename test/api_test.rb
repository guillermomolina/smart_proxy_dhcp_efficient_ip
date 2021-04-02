require 'test_helper'
require 'SOLIDserver'
require 'smart_proxy_efficient_ip/api'

class ApiTest < Test::Unit::TestCase
  def setup
    @connection = ::SOLIDserver::SOLIDserver.new('10.10.10.10', 'username', 'password')
    @api = ::Proxy::DHCP::EfficientIp::Api.new(@connection)
  end

  def test_find_subnet
    network_address = '192.168.45.0'
    subnet = { 'subnet_id' => '142', 'subnet_size' => '256' }
    server_response = stub(body: [subnet].to_json)

    @connection
      .expects(:ip_subnet_list)
      .with(where: "start_hostaddr='#{network_address}' and is_terminal='1'", limit: 1)
      .returns(server_response)

    assert_equal @api.find_subnet(network_address), subnet
  end

  def test_find_subnets
    subnets = [
      { 'subnet_id' => '142', 'subnet_size' => '256' },
      { 'subnet_id' => '182', 'subnet_size' => '256' },
      { 'subnet_id' => '108', 'subnet_size' => '256' },
    ]
    server_response = stub(body: subnets.to_json)

    @connection
      .expects(:ip_subnet_list)
      .with(where: "is_terminal='1' and start_hostaddr!='0.0.0.0'")
      .returns(server_response)

    assert_equal @api.subnets, subnets
  end

  def test_find_free
    network_address = '192.168.45.0'
    start_ip = '192.168.45.5'
    end_ip = '192.168.45.25'
    subnet = { 'subnet_id' => '142', 'subnet_size' => '256' }
    free_address = { 'hostaddr' => '192.168.45.11' }
    subnet_response = stub(body: [subnet].to_json)
    server_response = stub(body: [free_address].to_json)

    @connection
      .expects(:ip_subnet_list)
      .with(where: "start_hostaddr='#{network_address}' and is_terminal='1'", limit: 1)
      .returns(subnet_response)
    @connection
      .expects(:ip_address_find_free)
      .with(subnet_id: subnet['subnet_id'], begin_addr: start_ip, end_addr: end_ip, max_find: 1)
      .returns(server_response)

    assert_equal @api.find_free(network_address, start_ip, end_ip), free_address
  end

  def test_find_record
    address = '192.168.45.92'
    record = { 'name' => 'Vincent', 'hostaddr' => address }
    server_response = stub(body: [record].to_json)

    @connection
      .expects(:ip_address_list)
      .with(where: "type='ip' and (hostaddr='#{address}' or mac_addr='#{address}')", limit: 1)
      .returns(server_response)

    assert_equal @api.find_record(address), record
  end

  def test_find_records
    address = '192.168.45.92'
    records = [
      { 'name' => 'Vincent', 'hostaddr' => address },
      { 'name' => 'Tom', 'hostaddr' => address },
    ]
    server_response = stub(body: records.to_json)

    @connection
      .expects(:ip_address_list)
      .with(where: "type='ip' and (hostaddr='#{address}' or mac_addr='#{address}')")
      .returns(server_response)

    assert_equal @api.find_records(address), records
  end

  def test_hosts
    network_address = '192.168.45.0'
    hosts = [
      { 'name' => 'Vincent', 'hostaddr' => '192.168.45.101' },
      { 'name' => 'Tom', 'hostaddr' => '192.168.45.94' },
    ]
    subnet = { 'subnet_id' => '192', 'subnet_size' => '256', 'start_hostaddr' => network_address }
    subnet_response = stub(body: [subnet].to_json)
    server_response = stub(body: hosts.to_json)

    @connection
      .expects(:ip_subnet_list)
      .with(where: "start_hostaddr='#{network_address}' and is_terminal='1'", limit: 1)
      .returns(subnet_response)
    @connection
      .expects(:ip_address_list)
      .with(where: "subnet_id=#{subnet['subnet_id']} and dhcphost_id > 0")
      .returns(server_response)

    assert_equal @api.hosts(network_address), hosts
  end

  def test_leases
    network_address = '192.168.47.0'
    addresses = [
      { 'dhcplease_id' => '78' },
      { 'dhcplease_id' => '21' },
    ]
    leases = [
      { 'dhcplease_id' => '78', 'dhcplease_name' => 'ABC' },
      { 'dhcplease_id' => '21', 'dhcplease_name' => 'CBD' },
    ]
    subnet = { 'subnet_id' => '192', 'subnet_size' => '256', 'start_hostaddr' => network_address }
    subnet_response = stub(body: [subnet].to_json)
    server_response = stub(body: addresses.to_json)
    leases_resposne = stub(body: leases.to_json)
    ids = addresses.map { |addr| addr['dhcplease_id'] }

    @connection
      .expects(:ip_subnet_list)
      .with(where: "start_hostaddr='#{network_address}' and is_terminal='1'", limit: 1)
      .returns(subnet_response)
    @connection
      .expects(:ip_address_list)
      .with(where: "subnet_id=#{subnet['subnet_id']} and dhcplease_id > 0")
      .returns(server_response)
    @connection
      .expects(:dhcp_lease_list)
      .with(where: "dhcplease_id IN (#{ids})")
      .returns(leases_resposne)

    assert_equal @api.leases(network_address), leases
  end

  def test_add_record
    network_address = '192.168.45.0'
    params = { 'ip' => '192.168.45.65', 'mac' => '1f:83:ea:ee:53:67', 'name' => 'Makita', 'network' => network_address }
    subnet = { 'subnet_id' => '192', 'site_name' => 'Houston', 'start_hostaddr' => network_address }
    subnet_response = stub(body: [subnet].to_json)

    @connection
      .expects(:ip_subnet_list)
      .with(where: "start_hostaddr='#{network_address}' and is_terminal='1'", limit: 1)
      .returns(subnet_response)
    @connection
      .expects(:ip_address_add)
      .with(site_name: subnet['site_name'], ip_addr: params['ip'], mac_addr: params['mac'], name: params['name'])
      .once

    @api.add_record(params)
  end

  def test_delete_record
    subnet_params = { 'subnet_id' => '192', 'site_name' => 'Houston' }
    subnet = stub(network: '192.168.45.0')
    record = stub(subnet: subnet, ip: '192.168.45.65')
    subnet_response = stub(body: [subnet_params].to_json)

    @connection
      .expects(:ip_subnet_list)
      .with(where: "start_hostaddr='#{subnet.network}' and is_terminal='1'", limit: 1)
      .returns(subnet_response)
    @connection
      .expects(:ip_address_delete)
      .with(site_name: subnet_params['site_name'], hostaddr: record.ip)
      .once

    @api.delete_record(record)
  end
end
