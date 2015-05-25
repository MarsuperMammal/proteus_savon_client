# Use the Savon SOAP Client
# gem install savon
# See http://savonrb.com/version2/client.html
require 'savon'
require 'ipaddr'

module Bluecat
  class Api

    # Creates read and write methods for new attributes.
    attr_accessor :auth_cookies, :client
    def initialize

      # Connect to Bluecat SOAP API
      @client = Savon.client(wsdl: 'https://ipam-testlab.tycoelectronics.net:/Services/API?wsdl')
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
      user = ''
      pass = ''
      response = client.call(:login) do
        message username: user, password: pass
      end
      # Auth cookies are required for subsequent method invocations
      @auth_cookies = response.http.cookies
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
      entity_props = response.body[:get_host_records_by_hint_response][:return][:item]
      entity_props.each do |line|
        entity_id = line[:id]
        client.call(:get_linked_entities) do |ctx|
          ctx.cookies auth_cookies
          ctx.message entityId: entity_id, type: "RecordWithLink", start: start, count: count
        end
      p fqdn
      p
      end
    end

    # Removes a system's DNS Host Record, and all records linked to it's Host Record.
    def remove_sys_dns_identity(fqdn, start=0, count=1)
      client.call(:get_host_records_by_hint) do |ctx|
        ctx.cookies auth_cookies
        ctx.message start: start, count: count, options: "hint=#{fqdn}"
      end
      host_record_id = response.body[:get_host_records_by_hint_response][:return][:item][:id]
      client.call(:delete) do |ctx|
        ctx.cookies auth_cookies
        ctx.message objectId: host_record_id
      end
    end

    # Creates a systems Host Record and any Alias records it requires.
    def set_sys_host_record(view_id, fqdn, ipaddress, ttl=180, properties='')
      sys_host_response = client.call(:add_host_record) do |ctx|
        ctx.cookies auth_cookies
        ctx.message viewId: view_id, absoluteName: fqdn, addresses: ipaddress, ttl: ttl, properties: properties
      end
    end
  end
end
