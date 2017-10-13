
%centreon_newtestd_config = (
        1 => { date => '* * * * *', arguments => {
                                                    nmc_endpoint => 'http://192.168.6.84/nws/managementconsoleservice.asmx', 
                                                    timeout => 10,
                                                    host_template => 'generic-active-host', host_prefix => 'Robot-%s',
                                                    service_template => 'generic-passive-service', service_prefix => 'Scenario-%s',
                                                    poller_name => 'Central',
                                                    clapi_command => '/usr/share/centreon/www/modules/centreon-clapi/core/centreon', 
                                                    clapi_username => 'admin', clapi_password => 'centreon',
                                                    clapi_action_applycfg => 'POLLERRELOAD',
                                                    ListScenarioStatus => { search => 'All', instances => [] } 
                                                 } },
        2 => { date => '* * * * *', arguments => { 
                                                    nmc_endpoint => 'http://192.168.6.8/nws/managementconsoleservice.asmx',
                                                    nmc_username => 'admin', nmc_password => 'test',
                                                    timeout => 10,
                                                    host_template => 'generic-active-host', host_prefix => 'Robot-%s',
                                                    service_template => 'generic-passive-service', service_prefix => 'Scenario-%s',
                                                    poller_name => 'Central',
                                                    clapi_command => '/usr/share/centreon/www/modules/centreon-clapi/core/centreon', 
                                                    clapi_username => 'admin', clapi_password => 'centreon',
                                                    clapi_action_applycfg => 'POLLERRELOAD',
                                                    ListScenarioStatus => { search => 'Robot', instances => ['OSLO'] } 
                                                  } },
);

1;
