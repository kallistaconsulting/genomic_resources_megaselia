#!/bin/bash

# Initialize MariaDB if empty
#if [ ! -d "/var/lib/mysql/mysql" ]; then
#    mysql_install_db --user=mysql --datadir=/var/lib/mysql
#fi

#service mysql start
#mysql -u root < /init.sql
#service php8.1-fpm start
service nginx start
shiny-server &
sequenceserver --host 0.0.0.0 -d /data/blastdb/ -p 4567 > /var/log/sequenceserver.log 2>&1 &
http-server /jbrowse -p 3000 -a 0.0.0.0 &
tail -f /dev/null
