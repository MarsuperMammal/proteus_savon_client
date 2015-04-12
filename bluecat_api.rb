# Use the Savon SOAP Client
# gem install savon
# See http://savonrb.com/version2/client.html
require 'savon'

module Bluecat
  class Api
    #Production ipam WSDL
    WsdlUrl = 'https://ipam.tycoelectronics.net:/Services/API?wsdl'

    # Service account with API rights
    User = 'te0s0067'
    Pass = '/Thgq0*0wa'

    # Creates read and write methods for new attributes.
    attr_accessor :auth_cookies
    attr_accessor :client

    def initialize
      # Connect to Bluecat SOAP API
      @client = Savon.client(wsdl: WsdlUrl)
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
        message username: User, password: Pass
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
  end
end