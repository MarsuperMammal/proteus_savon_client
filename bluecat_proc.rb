require './bluecat_api.rb'
require 'yaml'
cleanup = File.open("./cleanup.list", "r")
cleanup.each_line do |fqdn_in|
  fqdn = fqdn_in.chomp
  poc = Bluecat::Api.new('https://ipam.tycoelectronics.net:/Services/API?wsdl','te0s0067','/Thgq0*0wa')
  File.open("./output.yaml", "w") do |file|
    output = poc.check_sys_linked_records(fqdn)
    file.write output.to_yaml
    end
  end
cleanup.close
