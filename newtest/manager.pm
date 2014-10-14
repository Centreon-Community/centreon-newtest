
package newtest::manager;

use strict;
use warnings;
use newtest::stubs::ManagementConsoleService;
use newtest::stubs::errors;
use centreon::common::db;
use centreon::common::misc;
use Date::Parse;

my %handlers = (TERM => {}, DIE => {});

my %map_scenario_status = (
    Available => 0,
    Warning => 1,
    Failed => 2,
    Suspended => 2,
    Canceled => 2,
    Unknown => 3,
    OutOfRange => 3,
);

my %map_newtest_units = (
    Second => 's',
    Millisecond => 'ms',
    BytePerSecond => 'Bps',
    UnitLess => '',
    Unknown => '',
);

my %map_service_status = (
    0 => 'OK', 
    1 => 'WARNING', 
    2 => 'CRITICAL', 
    3 => 'UNKNOWN', 
    4 => 'PENDING',
);

sub new {
    my ($class, %options) = @_;
    my $self  = {};
    bless $self, $class;

    $SOAP::Constants::PREFIX_ENV = 'SOAP-ENV';
    $self->{instance} = new ManagementConsoleService();
    $self->{timeout} = defined($options{timeout}) ? $options{timeout} : 5;
    $self->{clapi_generate_config_timeout} = defined($options{clapi_generate_config_timeout}) ? $options{clapi_generate_config_timeout} : 180;
    $self->{clapi_timeout} = defined($options{clapi_timeout}) ? $options{clapi_timeout} : 10;
    $self->{logger} = $options{logger};
    $self->{centreon_config} = $options{centreon_config};
    
    my @values = ('endpoint', 'cmdFile', 'host_template', 'host_prefix', 'service_template', 
                  'service_prefix', 'poller_name', 
                  'clapi_command', 'clapi_username', 'clapi_password', 'clapi_action_applycfg');
    foreach (@values) {
        if (!defined($options{$_}) || $options{$_} eq '') {
            $self->{logger}->writeLogError("Cannot create object: '$_' configuration is missing or empty.");
            return undef;
        }
        $self->{$_} = $options{$_};
    }
    
    # list from robot/scenario from db
    #   Format = { robot_name1 => { scenario1 => { last_execution_time => xxxx }, scenario2 => { } }, ... }
    $self->{db_newtest} = {};
    $self->{api_newtest} = {};
    $self->{poller_id} = undef;
    $self->{must_push_config} = 0;
    $self->{external_commands} = [];
    $self->{perfdatas} = [];
    $self->{cache_robot_list_results} = undef;
 
    # DB Connections
    $self->{centreon_db_centreon} = centreon::common::db->new(db => $self->{centreon_config}->{centreon_db},
                                                              host => $self->{centreon_config}->{db_host},
                                                              port => $self->{centreon_config}->{db_port},
                                                              user => $self->{centreon_config}->{db_user},
                                                              password => $self->{centreon_config}->{db_passwd},
                                                              force => 0,
                                                              logger => $self->{logger});
    return undef if ($self->{centreon_db_centreon}->connect() == -1);
    $self->{centreon_db_centstorage} = centreon::common::db->new(db => $self->{centreon_config}->{centstorage_db},
                                                                 host => $self->{centreon_config}->{db_host},
                                                                 port => $self->{centreon_config}->{db_port},
                                                                 user => $self->{centreon_config}->{db_user},
                                                                 password => $self->{centreon_config}->{db_passwd},
                                                                 force => 0,
                                                                 logger => $self->{logger});
    return undef if ($self->{centreon_db_centstorage}->connect() == -1);

    $self->set_signal_handlers;
    return $self;
}

sub set_signal_handlers {
    my $self = shift;

    $SIG{TERM} = \&class_handle_TERM;
    $handlers{TERM}->{$self} = sub { $self->handle_TERM() };
    $SIG{__DIE__} = \&class_handle_DIE;
    $handlers{DIE}->{$self} = sub { $self->handle_DIE($_[0]) };
}

sub class_handle_TERM {
    foreach (keys %{$handlers{TERM}}) {
        &{$handlers{TERM}->{$_}}();
    }
    exit(0);
}

sub class_handle_DIE {
    my ($msg) = @_;

    foreach (keys %{$handlers{DIE}}) {
        &{$handlers{DIE}->{$_}}($msg);
    }
}

sub handle_DIE {
    my $self = shift;
    my $msg = shift;

    $self->{logger}->writeLogInfo("die: $msg");
    exit(0);
}

sub handle_TERM {
    my $self = shift;
    $self->{logger}->writeLogInfo("$$ Receiving order to stop...");
    die("Quit Job Manager");
}

sub perfdata_add {
    my ($self, %options) = @_;
   
    my $perfdata = {label => '', value => '', unit => '', warning => '', critical => '', min => '', max => ''}; 
    foreach (keys %options) {
        next if (!defined($options{$_}));
        $perfdata->{$_} = $options{$_};
    }
    $perfdata->{label} =~ s/'/''/g;
    push @{$self->{perfdatas}}, $perfdata;
}

sub add_output {
    my ($self, %options) = @_;
    
    my $str = $map_service_status{$self->{current_status}} . ': ' . $self->{current_text} . '|';
    foreach my $perf (@{$self->{perfdatas}}) {
        $str .= " '" . $perf->{label} . "'=" . $perf->{value} . $perf->{unit} . ";" . $perf->{warning} . ";" . $perf->{critical} . ";" . $perf->{min} . ";" . $perf->{max};
    }
    $self->{perfdatas} = [];
    
    $self->push_external_cmd(cmd => 'PROCESS_SERVICE_CHECK_RESULT;' . $options{host_name} . ';' . 
                                        $options{service_name} . ';' . $self->{current_status} . ';' . $str,
                             time => $options{time});
}

sub convert_measure {
    my ($self, %options) = @_;
    
    if (defined($map_newtest_units{$options{unit}}) && 
        $map_newtest_units{$options{unit}} eq 'ms') {
        $options{value} /= 1000;
        $options{unit} = 's';
    }
    return ($options{value}, $options{unit});
}

sub get_poller_id {
    my ($self, %options) = @_;
    
    my ($status, $stmt) = $self->{centreon_db_centreon}->query('SELECT id FROM nagios_server WHERE name = ' . 
                    $self->{centreon_db_centreon}->quote($self->{poller_name}));
    if ($status == -1) {
        $self->{logger}->writeLogError("Cannot get poller id for poller '" . $self->{poller_name} . "'.");
        return 1;
    }
    
    my $data = $stmt->fetchrow_hashref();
    if (!defined($data)) {
        $self->{logger}->writeLogError("Cannot find poller id for poller '" . $self->{poller_name} . "'.");
        return 1;
    }
    
    $self->{poller_id} = $data->{id};
    return 0;
}

sub get_centreondb_cache {
    my ($self, %options) = @_;
    
    my $request = 'SELECT host.host_name, service.service_description 
                        FROM host 
                        LEFT JOIN (host_service_relation, service) ON (host_service_relation.host_host_id = host.host_id AND service.service_id = host_service_relation.service_service_id AND service.service_description LIKE ' . $self->{centreon_db_centreon}->quote($self->{service_prefix}) . ') 
                        WHERE host_name LIKE ' . $self->{centreon_db_centreon}->quote($self->{host_prefix});
    $request =~ s/%s/%/g;
    my ($status, $stmt) = $self->{centreon_db_centreon}->query($request);
    if ($status == -1) {
        $self->{logger}->writeLogError("Cannot get robot/scenarios list from centreon db.");
        return 1;
    }
    
    while ((my $data = $stmt->fetchrow_hashref())) {
        $self->{db_newtest}->{$data->{host_name}} = {} if (!defined($self->{db_newtest}->{$data->{host_name}}));
        if (defined($data->{service_description})) {
            $self->{db_newtest}->{$data->{host_name}}->{$data->{service_description}} = {};
        }
    }

    return 0;
}

sub get_centstoragedb_cache {
    my ($self, %options) = @_;
    
    my $request = 'SELECT hosts.name, services.description, services.last_check 
                        FROM hosts LEFT JOIN services ON (services.host_id = hosts.host_id AND services.description LIKE ' . $self->{centreon_db_centstorage}->quote($self->{service_prefix}) . ')  
                        WHERE name like ' . $self->{centreon_db_centstorage}->quote($self->{host_prefix});
    $request =~ s/%s/%/g;
    my ($status, $stmt) = $self->{centreon_db_centstorage}->query($request);
    if ($status == -1) {
        $self->{logger}->writeLogError("Cannot get robot/scenarios list from centstorage db.");
        return 1;
    }
    
    while ((my $data = $stmt->fetchrow_hashref())) {
        if (!defined($self->{db_newtest}->{$data->{name}})) {
            $self->{logger}->writeLogError("Host '" . $data->{name}  . "'is in censtorage DB but not in centreon config...");
            next;
        }
        if (defined($data->{description}) && !defined($self->{db_newtest}->{$data->{name}}->{$data->{description}})) {
            $self->{logger}->writeLogError("Host Scenario '" . $data->{name}  . "/" .  $data->{description} . "' is in censtorage DB but not in centreon config...");
            next;
        }
        
        if (defined($data->{description})) {
            $self->{db_newtest}->{$data->{name}}->{$data->{description}}->{last_execution_time} = $data->{last_check};
        }
    }

    return 0;
}

sub clapi_execute {
    my ($self, %options) = @_;
    
    my $cmd = $self->{clapi_command} . " -u '" . $self->{clapi_username} . "' -p '" . $self->{clapi_password} . "' " . $options{cmd};
    my ($lerror, $stdout, $exit_code) = centreon::common::misc::backtick(command => $cmd,
                                                                         logger => $self->{logger},
                                                                         timeout => $options{timeout},
                                                                         wait_exit => 1
                                                                         );
    if ($lerror == -1 || ($exit_code >> 8) != 0) {
        $self->{logger}->writeLogError("Clapi execution problem for command $cmd : " . $stdout);
        return -1;
    }

    return 0;
}

sub push_external_cmd {
    my ($self, %options) = @_;
    my $time = defined($options{time}) ? $options{time} : time();

    push @{$self->{external_commands}}, 
        'EXTERNALCMD:' . $self->{poller_id} . ':[' . $time . '] ' . $options{cmd};
}

sub submit_external_cmd {
    my ($self, %options) = @_;
    
    foreach my $cmd (@{$self->{external_commands}}) {
        my ($lerror, $stdout, $exit_code) = centreon::common::misc::backtick(command => '/bin/echo "' . $cmd . '" >> ' . $self->{cmdFile},
                                                                             logger => $self->{logger},
                                                                             timeout => 5,
                                                                             wait_exit => 1
                                                                            );
        if ($lerror == -1 || ($exit_code >> 8) != 0) {
            $self->{logger}->writeLogError("Clapi execution problem for command $cmd : " . $stdout);
            return -1;
        }
    }
}

sub push_config {
    my ($self, %options) = @_;

    if ($self->{must_push_config} == 1) {
        $self->{logger}->writeLogInfo("Generation config for '$self->{poller_name}':");
        if ($self->clapi_execute(cmd => '-a POLLERGENERATE -v ' . $self->{poller_id},
                                 timeout => $self->{clapi_generate_config_timeout}) != 0) {
            $self->{logger}->writeLogError("Generation config for '$self->{poller_name}': failed");
            return ;
        }
        $self->{logger}->writeLogError("Generation config for '$self->{poller_name}': succeeded.");
        
        $self->{logger}->writeLogInfo("Move config for '$self->{poller_name}':");
        if ($self->clapi_execute(cmd => '-a CFGMOVE -v ' . $self->{poller_id},
                                timeout => $self->{clapi_timeout}) != 0) {
            $self->{logger}->writeLogError("Move config for '$self->{poller_name}': failed");
            return ;
        }
        $self->{logger}->writeLogError("Move config for '$self->{poller_name}': succeeded.");
        
        $self->{logger}->writeLogInfo("Restart/Reload config for '$self->{poller_name}':");
        if ($self->clapi_execute(cmd => '-a ' . $self->{clapi_action_applycfg} . ' -v ' . $self->{poller_id},
                                timeout => $self->{clapi_timeout}) != 0) {
            $self->{logger}->writeLogError("Restart/Reload config for '$self->{poller_name}': failed");
            return ;
        }
        $self->{logger}->writeLogError("Restart/Reload config for '$self->{poller_name}': succeeded.");
    }
}

sub get_newtest_diagnostic {
    my ($self, %options) = @_;
    
    my $result = $self->{instance}->ListMessages('Instance', 30, 'Diagnostics', [$options{scenario}, $options{robot}]);
    if (defined(my $com_error = newtest::stubs::errors::get_error())) {
        $self->{logger}->writeLogError("NewTest API error 'ListMessages' method: " . $com_error);
        return -1;
    }
    
    if (!(ref($result) && defined($result->{MessageItem}))) {
        $self->{logger}->writeLogError("No diagnostic found for scenario: " . $options{scenario} . '/' . $options{robot});
        return 1;
    }
    if (ref($result->{MessageItem}) eq 'HASH') {
            $result->{MessageItem} = [$result->{MessageItem}];
    }
    
    my $macro_value = '';
    my $macro_append = ''; 
    foreach my $item (@{$result->{MessageItem}}) {
        if (defined($item->{SubCategory})) {
            $macro_value .= $macro_append . $item->{SubCategory} . ':' . $item->{Id};
            $macro_append = '|';
        }
    }
    
    if ($macro_value ne '') {
        $self->push_external_cmd(cmd => 'CHANGE_CUSTOM_SVC_VAR;' . $options{host_name} . ';' . 
                                        $options{service_name} . ';NEWTEST_MESSAGEID;' . $macro_value);
    }
    return 0;
}

sub get_scenario_results {
    my ($self, %options) = @_;
    
    # Already test the robot but no response
    if (defined($self->{cache_robot_list_results}->{$options{robot}}) && 
        !defined($self->{cache_robot_list_results}->{$options{robot}}->{ResultItem})) {
        $self->{current_text} = sprintf("No result avaiblable for scenario '%s'", $options{scenario});
        $self->{current_status} = 3;
        return 1;
    }
    if (!defined($self->{cache_robot_list_results}->{$options{robot}})) {
        my $result = $self->{instance}->ListResults('Robot', 30, [$options{robot}]);
        if (defined(my $com_error = newtest::stubs::errors::get_error())) {
            $self->{logger}->writeLogError("NewTest API error 'ListResults' method: " . $com_error);
            return -1;
        }
        
        if (!(ref($result) && defined($result->{ResultItem}))) {
            $self->{cache_robot_list_results}->{$options{robot}} = {};
            $self->{logger}->writeLogError("No results found for robot: " . $options{robot});
            return 1;
        }
        
        if (ref($result->{ResultItem}) eq 'HASH') {
            $result->{ResultItem} = [$result->{ResultItem}];
        }
        $self->{cache_robot_list_results}->{$options{robot}} = $result;
    }
    
    # stop at first
    foreach my $result (@{$self->{cache_robot_list_results}->{$options{robot}}->{ResultItem}}) {
        if ($result->{MeasureName} eq $options{scenario}) {
            my ($value, $unit) = $self->convert_measure(value => $result->{ExecutionValue},
                                                        unit => $result->{MeasureUnit}
                                                        );
            $self->{current_text} = sprintf("Execution status '%s'. Scenario '%s' total duration is %d%s.",
                                            $result->{ExecutionStatus}, $options{scenario}, 
                                            $value, $unit
                                            );
            $self->perfdata_add(label => $result->{MeasureName}, unit => $unit, 
                                value => sprintf("%d", $value), 
                                min => 0);
            
            $self->get_newtest_extra_metrics(scenario => $options{scenario}, robot => $options{robot},
                                             id => $result->{Id});
            return 0;
        }
    }
    
    $self->{logger}->writeLogError("No result found for scenario: " . $options{scenario} . '/' . $options{robot});
    return 1;
}

sub get_newtest_extra_metrics {
    my ($self, %options) = @_;
    
    my $result = $self->{instance}->ListResultChildren($options{id});
    if (defined(my $com_error = newtest::stubs::errors::get_error())) {
        $self->{logger}->writeLogError("NewTest API error 'ListResultChildren' method: " . $com_error);
        return -1;
    }
    
    if (!(ref($result) && defined($result->{ResultItem}))) {
        $self->{logger}->writeLogError("No extra metrics found for scenario: " . $options{scenario} . '/' . $options{robot});
        return 1;
    }
    
    if (ref($result->{ResultItem}) eq 'HASH') {
        $result->{ResultItem} = [$result->{ResultItem}];
    }
    foreach my $item (@{$result->{ResultItem}}) {
        $self->perfdata_add(label => $item->{MeasureName}, unit => $map_newtest_units{$item->{MeasureUnit}}, 
                            value => $item->{ExecutionValue});
    }
    return 0;
}

sub get_newtest_scenarios {
    my ($self, %options) = @_;
    
    $self->{instance}->proxy($self->{endpoint}, timeout => $self->{timeout});
    my $result = $self->{instance}->ListScenarioStatus($options{ListScenarioStatus}->{search}, 
                                                       0, 
                                                       $options{ListScenarioStatus}->{instances});
    if (defined(my $com_error = newtest::stubs::errors::get_error())) {
        $self->{logger}->writeLogError("NewTest API error 'ListScenarioStatus' method: " . $com_error);
        return -1;
    }
    
    if (defined($result->{InstanceScenarioItem})) {
        if (ref($result->{InstanceScenarioItem}) eq 'HASH') {
            $result->{InstanceScenarioItem} = [$result->{InstanceScenarioItem}];
        }

        foreach my $scenario (@{$result->{InstanceScenarioItem}}) {
            my $scenario_name = $scenario->{MeasureName};
            my $robot_name = $scenario->{RobotName};
            my $last_check = sprintf("%d", Date::Parse::str2time($scenario->{LastMessageUtc}, 'UTC'));
            my $host_name = sprintf($self->{host_prefix}, $robot_name);
            my $service_name = sprintf($self->{service_prefix}, $scenario_name);
            $self->{current_status} = $map_scenario_status{$scenario->{Status}};
            $self->{current_text} = '';
            
            # Add host config
            if (!defined($self->{db_newtest}->{$host_name})) {
                $self->{logger}->writeLogInfo("Create host '$host_name'");
                if ($self->clapi_execute(cmd => '-o HOST -a ADD -v "' . $host_name . ';' . $host_name . ';127.0.0.1;' . $self->{host_template} . ';' . $self->{poller_name} . ';"',
                                         timeout => $self->{clapi_timeout}) == 0) {
                    $self->{db_newtest}->{$host_name} = {};
                    $self->{must_push_config} = 1;
                    $self->{logger}->writeLogInfo("Create host '$host_name' succeeded.");
                }
            }
            
            # Add service config
            if (defined($self->{db_newtest}->{$host_name}) && !defined($self->{db_newtest}->{$host_name}->{$service_name})) {
                $self->{logger}->writeLogInfo("Create service '$service_name' for host '$host_name':");
                if ($self->clapi_execute(cmd => '-o SERVICE -a ADD -v "' . $host_name . ';' . $service_name . ';' . $self->{service_template} . '"',
                                         timeout => $self->{clapi_timeout}) == 0) {
                    $self->{db_newtest}->{$host_name}->{$service_name} = {};
                    $self->{must_push_config} = 1;
                    $self->{logger}->writeLogInfo("Create service '$service_name' for host '$host_name' succeeded.");
                }
            }
            
            # Check if new message
            if (defined($self->{db_newtest}->{$host_name}->{$service_name}->{last_execution_time}) &&
                $last_check <= $self->{db_newtest}->{$host_name}->{$service_name}->{last_execution_time}) {
                $self->{logger}->writeLogInfo("Skip: service '$service_name' for host '$host_name' already submitted.");
                next;
            }
            
            if ($self->{current_status} == 2) {
                $self->get_newtest_diagnostic(scenario => $scenario_name, robot => $robot_name,
                                              host_name => $host_name, service_name => $service_name);
            }
            
            if ($self->get_scenario_results(scenario => $scenario_name, robot => $robot_name,
                                            host_name => $host_name, service_name => $service_name) == 1) {
                $self->{current_text} = sprintf("No result avaiblable for scenario '%s'", $scenario_name);
                $self->{current_status} = 3;
            }
            $self->add_output(time => $last_check, host_name => $host_name, service_name => $service_name);
        }
    }

    return 0;
}

sub run {
    my ($self, %options) = @_;
    
    return -1 if ($self->get_poller_id());
    return -1 if ($self->get_centreondb_cache());
    return -1 if ($self->get_centstoragedb_cache());
    
    return -1 if ($self->get_newtest_scenarios(%options));   

    $self->push_config();
    $self->submit_external_cmd();
    
    return 0;
}

1;
