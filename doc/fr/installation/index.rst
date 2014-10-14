============
Installation
============

Pré-Requis
==========

Préconisations logicielles
``````````````````````````

Le daemon "centreon-newtestd" est testé et validé sur red-hat 5 et 6 avec des rpms. 
L'installation sur d'autres environnements n'est pas exclu mais non présenté dans ce document (Debian, ...).

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
    Le daemon "centreon-newtestd" fourni par Merethis est conçu pour fonctionner Centreon 2.5 (CES 2.2 ou CES 3), il ne fonctionne pas avec Centreon 2.4.

Localisation du daemon
``````````````````````````

Le daemon "centreon-newtestd" doit être installé sur le serveur Central Centreon. Les ressources minimales requises sont :

* RAM : 128 Mo.
* CPU : Cela dépend du nombre de scénarios newtest.

Installation de centreon-newtestd - Environnement centos/rhel 5
===============================================================

Pré-requis
```````````````````````````````````````

======================= ===================== ======================
Dépendance               Version               Dépôt
======================= ===================== ======================
perl-Schedule-Cron           1.01             ces base
perl-SOAP-Lite               0.712            ces base
perl-TimeDate                1.16             redhat/centos base
perl-centreon-base           2.5.x            ces base
======================= ===================== ======================

Installation de centreon-newtestd par rpm
`````````````````````````````````````````

Installer le daemon::

  root # yum install centreon-newtestd

Installation de centreon-newtestd par les sources
`````````````````````````````````````````````````

Télécharger l'archive de « centreon-newtestd ».

Installer les fichiers::
  
  root # tar zxvf centreon-newtestd-x.x.x.tar.gz
  root # cd centreon-newtestd-x.x.x
  root # cp centreon_newtestd /usr/bin/
  
  root # mkdir -p /etc/centreon
  root # cp centreon_newtestd-conf.pm /etc/centreon/centreon_newtestd.pm
  root # cp centreon_newtestd-init /etc/init.d/centreon_newtestd
  
  root # mkdir -p /usr/lib/perl5/vendor_perl/5.8.8/centreon/newtest/
  root # cp -R newtest/* /usr/lib/perl5/vendor_perl/5.8.8/centreon/newtest/

Activer le daemon « centreon-newtestd » au démarrage::
  
  root # chkconfig --level 2345 centreon_newtestd on

Installation de centreon-newtestd - Environnement centos/rhel 6
===============================================================

Pré-requis
```````````````````````````````````````

======================= ===================== ======================
Dépendance               Version               Dépôt
======================= ===================== ======================
perl-Schedule-Cron           1.01             ces base
perl-SOAP-Lite               0.710            redhat/centos base
perl-TimeDate                1.16             redhat/centos base
perl-centreon-base           2.5.x            ces base
======================= ===================== ======================

Installation de centreon-newtestd par rpm
`````````````````````````````````````````

Installer le daemon::

  root # yum install centreon-newtestd

Installation de centreon-newtestd par les sources
`````````````````````````````````````````````````

Télécharger l'archive de « centreon-newtestd ».

Installer les fichiers::
  
  root # tar zxvf centreon-newtestd-x.x.x.tar.gz
  root # cd centreon-newtestd-x.x.x
  root # cp centreon_newtestd /usr/bin/
  
  root # mkdir -p /etc/centreon
  root # cp centreon_newtestd-conf.pm /etc/centreon/centreon_newtestd.pm
  root # cp centreon_newtestd-init /etc/init.d/centreon_newtestd
  
  root # mkdir -p /usr/lib/perl5/vendor_perl/5.8.8/centreon/newtest/
  root # cp -R newtest/* /usr/lib/perl5/vendor_perl/5.8.8/centreon/newtest/

Activer le daemon « centreon-newtestd » au démarrage::
  
  root # chkconfig --level 2345 centreon_newtestd on



