require './bluecat_prov.rb'
fqdn=Facter.value(:fqdn)
prov=Bluecat::Api.new()
prov.remove_sys_dns_identity(fqdn)
p "DNS Enteries removed"
