require './bluecat_prov.rb'
ipaddress=Facter.value(:ipaddress)
fqdn=Facter.value(:fqdn)
prov=Bluecat::Api.new('https://ipam.tycoelectronics.net:/Services/API?wsdl','te0s0067','/Thgq0*0wa')
prov.set_sys_host_record('32746', fqdn, ipaddress)
p "A Record #{fqdn} created for #{ipaddress}"