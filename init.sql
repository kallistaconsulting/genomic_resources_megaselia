CREATE DATABASE drupal;
CREATE USER 'drupaluser'@'localhost' IDENTIFIED BY 'drupalpass';
GRANT ALL PRIVILEGES ON drupal.* TO 'drupaluser'@'localhost';
FLUSH PRIVILEGES;
