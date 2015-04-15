require './bluecat_api.rb'

poc = Bluecat::Api.new
poc.wsdl_url = 'https://ipam-testlab.tycoelectronics.net:/Services/API?wsdl'
poc.user = 'te0s0067'
poc.pass = '/Thgq0*0wa'
poc.check_sys_host_record(fqdn='ipam.tycoelectronics.net')