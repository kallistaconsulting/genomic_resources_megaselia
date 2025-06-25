# Install Drupal
mkdir /var/www
mkdir /var/www/html
cd /var/www/html

curl -Lo drupal.tar.gz https://www.drupal.org/files/projects/drupal-9.5.11.tar.gz
tar -xzf drupal.tar.gz --strip-components=1
rm drupal.tar.gz

# Install business themes used originally
cd /var/www/html/themes
wget https://ftp.drupal.org/files/projects/business-9.1.x-dev.tar.gz
tar xfv business-9.1.x-dev.tar.gz
rm business-9.1.x-dev.tar.gz

chown -R www-data:www-data /var/www/html

# Configure NGINX for Drupal
apt install -y nginx
cp /home/exouser/genomic_resources_megaselia/drupal/nginx-drupal.conf /etc/nginx/sites-available/default
cp -r /home/exouser/genomic_resources_megaselia/drupal/files /var/www/html/

# Setup MariaDB initial database
apt install -y php-fpm php-mysql php-gd php-xml php-mbstring php-curl
apt-get update && apt-get install -y mariadb-server
mariadb-secure-installation

mysql -u root -p < /home/exouser/genomic_resources_megaselia/drupal/init.sql
mysql -u root -p drupal < /home/exouser/genomic_resources_megaselia/drupal/drupal-db.sql

# Restart nginx for drupal boot
systemctl restart nginx

# Pull and Move Files for Download
mkdir /var/www/html/files
docker cp genome_browser:/var/www/genome-resources-megaselia/genome_files/Megaselia_abdita.repeatmasked_vNCBI.fa /var/www/html/files/
docker cp genome_browser:/var/www/genome-resources-megaselia/genome_files/Megaselia_vNCBI.gff3 /var/www/html/files/
docker cp genome_browser:/var/www/genome-resources-megaselia/genome_files/Megaselia.proteins_vNCBI.fa /var/www/html/files/
docker cp genome_browser:/var/www/genome-resources-megaselia/genome_files/Megaselia.transcripts_vNCBI.fa /var/www/html/files/
