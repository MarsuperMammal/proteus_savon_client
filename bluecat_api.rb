# Use the Savon SOAP Client
# gem install savon
# See http://savonrb.com/version2/client.html
require 'savon'
require 'yaml'
require 'ipaddr'
module Bluecat
  class Api

    # Creates read and write methods for new attributes.
    attr_accessor :auth_cookies, :client, :wsdl_url, :user, :pass
    def initialize (wsdl_url, user, pass)
      @wsdl_url = wsdl_url
      @user = user
      @pass = pass
      # Connect to Bluecat SOAP API
      @client = Savon.client(wsdl: @wsdl_url)
      unless client.nil?
        login
      else
        print "No client\n"
      end
      print "Got cookies %s\n" % auth_cookies
    end

    def login
      # Login using declared User
      # Block style invocation
      user = @user
      pass = @pass
      response = client.call(:login) do
        message username: user, password: pass
      end
      # Auth cookies are required for subsequent method invocations
      @auth_cookies = response.http.cookies
    end

    def system_info
      print "In system_info\n"
      hash = {}
      begin
        print "Calling get system_info\n"
        response = client.call(:get_system_info) do |ctx|
          ctx.cookies auth_cookies
        end
        print "Called get system_info\n"

        payload = response.body[:get_system_info_response][:return]
        print "Got payload %s\n" % payload
        kvs = unserialize_properties(payload)
        kvs.each do |k,v|
          hash[k.to_sym] = v
        end
        print "-----------------\n"
      rescue Exception => e
        print "Got Exception %s\n" % e.message
      end
      return hash
    end

    def system_test
      # Check for some operations
      unless client.operations.include? :login
        print "Login method missing from Bluecat Api\n"
      end
      unless client.operations.include? :get_system_info
        print "getSystemInfo method missing from Bluecat Api\n"
      else
        unless ( system_info[:address] =~ /\d{1,4}\.\d{1,4}\.\d{1,4}\.\d{1,4}/ ) == 0
          raise 'Failed system sanity test'
        end
      end
    end

    # Get list of configurations by Object Id
    def get_configurations(start=0, count=10)
      response = client.call(:get_entities) do |ctx|
        ctx.cookies auth_cookies
        ctx.message parentId: 0, type: 'Configuration', start: start, count: count
      end
      @config= canonical_items(response.body[:get_entities_response])
    end

    # Get list of IPv4 Blocks
    def get_ip4_blocks(parent_id, start=0, count=1)
      get_configurations()
      @config.each do |cfg_array|
        cfg = cfg_array[:id]
        response = client.call(:get_entities) do |ctx|
          ctx.cookies auth_cookies
          ctx.message parentId: cfg, type: 'IP4Block', start: start, count: count
        end
      blocks = canonical_items(response.body[:get_entities_response])
      end
    end

    # Get list of IPv4 Networks
    def get_ip4_networks(parent_id, start=0, count=1)
      get_configurations()
      @config.each do |cfg_array|
        cfg = cfg_array[:id]
        response = client.call(:get_entities) do |ctx|
          ctx.cookies auth_cookies
          ctx.message parentId: cfg, type: 'IP4Network', start: start, count: count
        end
      @networks = canonical_items(response.body[:get_entities_response])
      end
    end

    def get_dns_views(parent_id, start=0, count=1)
      @networks.each do |net_array|
        netid = net_array[:id]
        response = client.call(:get_entities) do |ctx|
          ctx.cookies auth_cookies
          ctx.message parentId: netid, type: 'View', start: start, count: count
        end
      @views = canonical_items(response.body[:get_entities_response])
      end
    end

    def get_dns_zones(parent_id, start=0, count=1)
      @views.each do |view_array|
        viewid = view_array[:id]
        response = client.call(:get_entities) do |ctx|
          ctx.cookies auth_cookies
          ctx.message parentId: viewid, type: 'Zone', start: start, count: count
        end
      @zones = canonical_items(response.body[:get_entities_response])
      end
    end

    # Checks if a system's hostname already exists in Proteus.
    def check_sys_host_record(fqdn, start=0, count=1)
      response = client.call(:get_host_records_by_hint) do |ctx|
        ctx.cookies auth_cookies
        ctx.message start: start, count: count, options: "hint=#{fqdn}"
      end
    end

    # Checks if a system's Host Record has any linked records (link Alias Records)
    def check_sys_linked_records(fqdn, start=0, count=10)
      host_record = client.call(:get_host_records_by_hint) do |ctx|
        ctx.cookies auth_cookies
        ctx.message start: start, count: count, options: "hint=#{fqdn}"
      end
      entity_props = host_record.hash[:envelope][:body][:get_host_records_by_hint_response][:return][:item]
      entity_props.each do |line|
        entity_id = line[:id]
        linked_records = client.call(:get_linked_entities) do |ctx|
          ctx.cookies auth_cookies
          ctx.message entityId: entity_id, type: "RecordWithLink", start: start, count: count
        end
        p fqdn
        p linked_records.hash
        end
    end

    def check_ip_linked_records(ipaddress, start=0, count=10)
      network_segments = {
            7936726 => IPAddr.new('10.125.117.0/24'),
            7936725 => IPAddr.new('10.125.116.0/24'),
            19282   => IPAddr.new('10.125.192.0/20'),
            19284   => IPAddr.new('10.125.208.0/20'),
            5129764 => IPAddr.new('10.125.121.192/26'),
            5129763 => IPAddr.new('10.125.121.128/26'),
            5129714 => IPAddr.new('10.125.121.64/26'),
            5129713 => IPAddr.new('10.125.121.0/26'),
            5129652 => IPAddr.new('10.125.120.128/25'),
            5129651 => IPAddr.new('10.125.120.0/25'),
            5129512 => IPAddr.new('10.125.119.192/26'),
            5129511 => IPAddr.new('10.125.119.128/26'),
            5129453 => IPAddr.new('10.125.119.64/26'),
            5129452 => IPAddr.new('10.125.119.0/26'),
            5129361 => IPAddr.new('10.125.118.128/25'),
            5129360 => IPAddr.new('10.125.118.0/25'),
            19270   => IPAddr.new('10.125.144.0/20'),
            4363738 => IPAddr.new('10.125.108.0/22'),
            4363737 => IPAddr.new('10.125.104.0/22'),
            4363654 => IPAddr.new('10.125.100.0/22'),
            4363653 => IPAddr.new('10.125.96.0/22'),
            3524173 => IPAddr.new('10.125.112.0/22'),
            2933855 => IPAddr.new('10.125.123.128/25'),
            2933854 => IPAddr.new('10.125.123.0/25'),
            2933816 => IPAddr.new('10.125.122.0/24'),
            2933232 => IPAddr.new('10.125.125.0/24'),
            2933231 => IPAddr.new('10.125.124.0/24'),
            19268   => IPAddr.new('10.125.128.0/20'),
            19274   => IPAddr.new('10.125.168.0/21'),
            19244   => IPAddr.new('10.125.0.0/20'),
            19252   => IPAddr.new('10.125.64.0/20'),
            19246   => IPAddr.new('10.125.16.0/20'),
            19248   => IPAddr.new('10.125.32.0/20'),
            19254   => IPAddr.new('10.125.80.0/20'),
            19250   => IPAddr.new('10.125.48.0/20'),
            19264   => IPAddr.new('10.125.126.0/24'),
            19276   => IPAddr.new('10.125.176.0/21'),
            19278   => IPAddr.new('10.125.184.0/22'),
            19280   => IPAddr.new('10.125.188.0/22'),
            19290   => IPAddr.new('10.125.240.0/21'),
            19292   => IPAddr.new('10.125.248.0/22'),
            19294   => IPAddr.new('10.125.252.0/22'),
            19266   => IPAddr.new('10.125.127.0/24'),
            19272   => IPAddr.new('10.125.160.0/21'),
            19286   => IPAddr.new('10.125.224.0/21'),
            19288   => IPAddr.new('10.125.232.0/21')
      }
      container_id = nil
      network_segments.each do |segment, value|
        if address.include?(Facter.value(ipaddress))
          container_id = segment
        end
      end
      ip_record = client.call(:get_ip4_address) do |ctx|
        ctx.cookies auth_cookies
        ctx.message containerId: container_id, address: ipaddress
      end
      ip_id = ip_record.hash[:envelope][:body][:get_ip4__address_response][:return][:item][:id]
      linked_ip_records = client.call(:get_linked_entities) do |ctx|
        ctx.cookies auth_cookies
        ctx.message entityId: ip_id, type: "HostRecord", start: 0, count: 10
      end
      a_records = linked_ip_records.hash[:envelope][:body][:get_linked_entities_response][:return][:item].each_index[:name]
      ar_id = linked_ip_records.hash[:envelope][:body][:get_linked_entities_response][:return][:item].each_index[:id]
      linked_records = client.call(:get_linked_entities) do |ctx|
        ctx.cookies auth_cookies
        ctx.message entityId: ar_id, type: "RecordWithLink", start: 0, count:10
      end
      alias_records = linked_records.hash[:envelope][:body][:get_linked_entities_response][:return][:item].each_idex[:name]
      p a_records
      p alias_records
    end

    # Removes External DNS Identities and Linked Records
    def remove_ext_dns_identity(ext_record, ext_view_id, start=0, count=1)
      ext_host_record = client.call(:get_entities_by_name) do |ctx|
        ctx.cookies auth_cookies
        ctx.message parentId: ext_view_id , name: ext_record, start: start, count: count
      end
      ext_host_record_id = ext_host_record.hash[:envelope][:body][:get_host_records_by_hint_response][:return][:item][:id]
      response = client.call(:delete) do |ctx|
        ctx.cookies auth_cookies
        ctx.message objectId: ext_host_record_id
      end
    end

    # Removes a system's DNS Host Record, and all records linked to it's Host Record.
    def remove_sys_dns_identity(fqdn, start=0, count=1)
      host_record = client.call(:get_host_records_by_hint) do |ctx|
        ctx.cookies auth_cookies
        ctx.message start: start, count: count, options: "hint=#{fqdn}"
      end
      host_record_id = host_record.hash[:envelope][:body][:get_host_records_by_hint_response][:return][:item][:id]
      response =  client.call(:delete) do |ctx|
        ctx.cookies auth_cookies
        ctx.message objectId: host_record_id
      end
    end

    # Adds and externally hosted, resolvable DNS record to Proteus, to anchor internal Aliases.
    def set_ext_record(ext_view_id, ext_record, view_id, ext_alias, ext_absolute_alias, ttl=180, properties='')
      ext_host_response = client.call(:add_external_host_record) do |ctx|
        ctx.cookies auth_cookies
        ctx.message view_id: ext_view_id, name: ext_record
      end

      ext_alias.each do
        ext_alias_response = client.call(:add_alias_record) do |ctx|
          ctx.cookies auth_cookies
          ctx.message viewId: view_id, absoluteName: ext_alias, linkedRecordName: ext_record, ttl: ttl, properties: properties
        end
        ext_absolute_alias.each do
          ext_absolue_alias_response = client.call(:add_alias_record) do |ctx|
          ctx.cookies auth_cookies
          ctx.message viewId: view_id, absoluteName: ext_absolute_alias, linkedRecordName: ext_record, ttl: ttl, properties: "overrideNamingPolicy=true"
          end
        end
      end
    end

    # Creates a systems Host Record and any Alias records it requires.
    def set_sys_host_record(view_id, fqdn, ipaddress, absolute_alias, ttl=180, properties='')
      sys_host_response = client.call(:add_host_record) do |ctx|
        ctx.cookies auth_cookies
        ctx.message viewId: view_id, absoluteName: fqdn, addresses: ipaddress, ttl: ttl, properties: properties
      end
      absolute_alias_response = client.call(:add_alias_record) do |ctx|
        ctx.cookies auth_cookies
        ctx.message viewId: view_id, absoluteName: absolute_alias, linkedRecordName: fqdn, ttl: ttl, properties: "overrideNamingPolicy=true"
      end
    end

    # Utility method to
    # Canonicalize SOAP sequences as array in case 0 or 1 item
     def canonical_items(hash)
       items = []
       unless hash[:return].nil?
         items = hash[:return][:item]
         items = [ items ].flatten
       end
       return items
     end

    # Utility methods to (un)serialize properties
    # Bluecat SOAP Api serializes properties as p1=v1|p2=v2|...
    def unserialize_properties(str)
      hash = {}
      str.split('|').each do |kvstr|
        k,v = kvstr.split('=')
        hash[ k.to_sym ] = v
      end
      hash
    end

    def serialize_properties(hash)
      str = ''
      first = true
      hash.each do |k,v|
        unless first
          str << '|'
        else
          first = false
        end
        str << "%s=%s" % [k,v]
      end
      str
    end

  end
end