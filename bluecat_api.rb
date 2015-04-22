# Use the Savon SOAP Client
# gem install savon
# See http://savonrb.com/version2/client.html
require 'savon'
require 'yaml'
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
      configurations = canonical_items(response.body[:get_entities_response])
    end

    # Get list of IPv4 Blocks
    def get_ip4_blocks(parent_id, start=0, count=1)
      response = client.call(:get_entities) do |ctx|
        ctx.cookies auth_cookies
        ctx.message parentId: parent_id, type: 'IP4Block', start: start, count: count
      end
      blocks = canonical_items(response.body[:get_entities_response])
    end

    # Get list of IPv4 Networks
    def get_ip4_networks(parent_id, start=0, count=1)
      response = client.call(:get_entities) do |ctx|
        ctx.cookies auth_cookies
        ctx.message parentId: parent_id, type: 'IP4Network', start: start, count: count
      end
      networks = canonical_items(response.body[:get_entities_response])
    end

    def get_dns_views(parent_id, start=0, count=1)
      response = client.call(:get_entities) do |ctx|
        ctx.cookies auth_cookies
        ctx.message parentId: parent_id, type: 'View', start: start, count: count
      end
      views = canonical_items(response.body[:get_entities_response])
    end

    def get_dns_zones(parent_id, start=0, count=1)
      response = client.call(:get_entities) do |ctx|
        ctx.cookies auth_cookies
        ctx.message parentId: parent_id, type: 'Zone', start: start, count: count
      end
      zones = canonical_items(response.body[:get_entities_response])
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

    def unserialize_properties(str)
      hash = {}
      str.split('|').each do |kvstr|
        k,v = kvstr.split('=')
        hash[ k.to_sym ] = v
      end
      hash
    end

    def canonical_items(hash)
      items = []
      unless hash[:return].nil?
        items = hash[:return][:item]
        items = [ items ].flatten
      end
      return items
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