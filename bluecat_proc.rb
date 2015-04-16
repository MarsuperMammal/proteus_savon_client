require './bluecat_api.rb'

poc = Bluecat::Api.new('https://ipam-testlab.tycoelectronics.net:/Services/API?wsdl','te0s0067','/Thgq0*0wa')
pry.binding
poc.system_info
poc.check_sys_host_record('pptappd03.tycoelectronics.net')