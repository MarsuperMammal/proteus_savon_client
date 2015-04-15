# Use the Savon SOAP Client
# gem install savon
# See http://savonrb.com/version2/client.html
require 'savon'

module Bluecat
  class Api
    wsdl_url = 'https://ipam-testlab.tycoelectronics.net:/Services/API?wsdl'
    user = 'te0s0067'
    pass = '/Thgq0*0wa'

    # Creates read and write methods for new attributes.
    attr_accessor :auth_cookies, :client
    def initialize
      # Connect to Bluecat SOAP API
      @client = Savon.client(wsdl: wsdl_url)
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

    # Checks if a system's hostname already exists in Proteus.
    def check_sys_host_record(fqdn, start=0, count=1)
      response = client_call(:getHostRecordsByHint) do |ctx|
        ctx.cookies auth_cookies
        ctx.message start: start, count: count, options: "hint=#{fqdn}"
      end
    end

    # Checks if a system's Host Record has any linked records (link Alias Records)
    def check_sys_linked_records(fqdn, start=0, count=10)
      entity_id = client_call(:getHostRecordsByHint) do |ctx|
        ctx.cookies auth_cookies
        ctx.message start: start, count: count, options: "hint=#{fqdn}"
        end
      response = client_call(:get_linked_entities) do |ctx|
        ctx.cookies auth_cookies
        ctx.message entityId: entity_id
        end
    end

    # Removes External DNS Identities and Linked Records
    def remove_ext_dns_identity(ext_record, ext_view_id, start=0, count=1)
      ext_host_record_id = client_call(:getEntitiesByName) do |ctx|
        ctx.cookies auth_cookies
        ctx.message parentId: ext_view_id , name: ext_record, start: start, count: count
      end
      response = client_call(:delete) do |ctx|
        ctx.cookies auth_cookies
        ctx.message objectId: ext_host_record_id
      end
    end

    # Removes a system's DNS Host Record, and all records linked to it's Host Record.
    def remove_sys_dns_identity(fqdn, start=0, count=1)
      host_record_id = client_call(:getHostRecordsByHint) do |ctx|
        ctx.cookies auth_cookies
        ctx.message start: start, count: count, options: "hint=#{fqdn}"
      end
      response =  client_call(:delete) do |ctx|
        ctx.cookies auth_cookies
        ctx.message objectId: host_record_id
      end
    end

    # Adds and externally hosted, resolvable DNS record to Proteus, to anchor internal Aliases.
    def set_ext_record(ext_view_id, ext_record, view_id, ext_alias, ext_absolute_alias, ttl=180, properties)
      ext_host_response = client_call(:addExternalHostRecord) do |ctx|
        ctx.cookies auth_cookies
        ctx.message view_id: ext_view_id, name: ext_record
      end
      ext_alias.each do
        ext_alias_response = client_call(:addAliasRecord) do |ctx|
          ctx.cookies auth_cookies
          ctx.message viewId: view_id, absoluteName: ext_alias, linkedRecordName:ext_record, ttl: ttl, properties: properties
        end
        ext_absolute_alias.each do
          ext_absolue_alias_response = client_call(:addAliasRecord) do |ctx|
          ctx.cookies auth_cookies
          ctx.message viewId: view_id, absoluteName: ext_absolute_alias, linkedRecordName: ext_record, ttl: ttl, properties: "overrideNamingPolicy=true"
          end
        end
      end
    end

    # Creates a systems Host Record and any Alias records it requires.
    def set_sys_host_record(view_id, fqdn, ipaddress, sys_alias, sys_record, absolute_alias, properties, ttl=180)
      sys_host_response = client_call(:addHostRecord) do |ctx|
        ctx.cookies auth_cookies
        ctx.message viewId: view_id, absoluteName: fqdn, addresses: ipaddress, ttl: ttl
      end
      sys_alias.each do
        sys_alias_response = client_call(:addAliasRecord) do |ctx|
          ctx.cookies auth_cookies
          ctx.message viewId: view_id, absoluteName: sys_alias, linkedRecordName: sys_record, ttl: ttl, properties: properties
        end
      end
      absolute_alias.each do
        absolute_alias_response = client_call(:addAliasRecord) do |ctx|
          ctx.cookies auth_cookies
          ctx.message viewId: view_id, absoluteName: absolute_alias, linkedRecordName: sys_record, ttl: ttl, properties: "overrideNamingPolicy=true"
        end
      end
    end
  end
end