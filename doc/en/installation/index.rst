============
Installation
============

Prerequisites
=============

Software Recommandations 
````````````````````````

The "centreon-newtestd" daemon has been tested on red-hat 5 and 6 with rpms.
Installation on other system is possible but is outside the scope of this document (Debian,...).

==================== =====================
Software              Version
==================== =====================
Perl                         5.8
Perl Schedule::Cron          1.01
Perl SOAP::Lite              0.71
Perl Date::Parse             1.16
centreon-common-perl         2.5
centreon-clapi               1.6.1
centcore                     2.5.x
==================== =====================

.. warning::
    The "centreon-newtestd" RPMS provided by Merethis is designed to work with Centreon 2.5 (CES 2.2 or CES 3), it does not work with Centreon 2.4.

Daemon location
```````````````

The "centreon-newtestd" daemon must be installed on Centreon Central server. Minimal used ressources are :

* RAM : 128 MB.
* CPU : it depends the number of newtest scenarios.

Centreon-newtestd Installation - centos/rhel 5 systems
======================================================

Requirements
```````````````````````````````

======================= ===================== ======================
Dependency               Version               Repository
======================= ===================== ======================
perl-Schedule-Cron           1.01             ces base
perl-SOAP-Lite               0.712            ces base
perl-TimeDate                1.16             redhat/centos base
perl-centreon-base           2.5.x            ces base
======================= ===================== ======================

centreon-newtestd Installation with rpm
```````````````````````````````````````

Install the daemon::

  root # yum install centreon-newtestd

centreon-newtestd Installation with source
``````````````````````````````````````````

Download « centreon-newtestd » archive, then install ::
  
  root # tar zxvf centreon-newtestd-x.x.x.tar.gz
  root # cd centreon-newtestd-x.x.x
  root # cp centreon_newtestd /usr/bin/
  
  root # mkdir -p /etc/centreon
  root # cp centreon_newtestd-conf.pm /etc/centreon/centreon_newtestd.pm
  root # cp centreon_newtestd-init /etc/init.d/centreon_newtestd
  
  root # mkdir -p /usr/lib/perl5/vendor_perl/5.8.8/centreon/newtest/
  root # cp -R newtest/* /usr/lib/perl5/vendor_perl/5.8.8/centreon/newtest/

Configure "centreon-newtestd" daemon to start at boot ::
  
  root # chkconfig --level 2345 centreon_newtestd on

Centreon-newtestd Installation - centos/rhel 6 systems
======================================================

Requirements
```````````````````````````````

======================= ===================== ======================
Dependency               Version               Repository
======================= ===================== ======================
perl-Schedule-Cron           1.01             ces base
perl-SOAP-Lite               0.710            redhat/centos base
perl-TimeDate                1.16             redhat/centos base
perl-centreon-base           2.5.x            ces base
======================= ===================== ======================

centreon-newtestd Installation with rpm
```````````````````````````````````````

Install the daemon::

  root # yum install centreon-newtestd

centreon-newtestd Installation with source
``````````````````````````````````````````

Download « centreon-newtestd » archive, then install ::
  
  root # tar zxvf centreon-newtestd-x.x.x.tar.gz
  root # cd centreon-newtestd-x.x.x
  root # cp centreon_newtestd /usr/bin/
  
  root # mkdir -p /etc/centreon
  root # cp centreon_newtestd-conf.pm /etc/centreon/centreon_newtestd.pm
  root # cp centreon_newtestd-init /etc/init.d/centreon_newtestd
  
  root # mkdir -p /usr/lib/perl5/vendor_perl/5.8.8/centreon/newtest/
  root # cp -R newtest/* /usr/lib/perl5/vendor_perl/5.8.8/centreon/newtest/

Configure "centreon-newtestd" daemon to start at boot ::
  
  root # chkconfig --level 2345 centreon_newtestd on
