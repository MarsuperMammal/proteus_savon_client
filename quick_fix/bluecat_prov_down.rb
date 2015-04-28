require './bluecat_prov.rb'
fqdn=Facter.value(:fqdn)
prov=Bluecat::Api.new('https://ipam.tycoelectronics.net:/Services/API?wsdl','te0s0067','/Thgq0*0wa')
prov.remove_sys_dns_identity(fqdn)
p "DNS Enteries removed"