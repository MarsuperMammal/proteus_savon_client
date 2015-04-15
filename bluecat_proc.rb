require './bluecat_api.rb'

poc = Bluecat::Api.new('https://ipam-testlab.tycoelectronics.net:/Services/API?wsdl','te0s0067','/Thgq0*0wa')
poc.check_sys_host_record('ipam.tycoelectronics.net')