# Genome Resources: Megaselia Start-Up

This project contains two components:

1. A Docker container  
2. A setup script for a pre-configured Drupal website to make finding and using tools easier.

Project tested on an Ubuntu 24.04 VM default image from Jetstream2, quad size, root dir of 40GB.

## 1) Container (Required)

The container provides a self-contained set of tools preinstalled and pre-configured with the genome data for *Megaselia abdita* (other versions available):

- **JBrowse 2** (genome browser)  
- **SequenceServer 2.0** (web-based BLAST server with links back to JBrowse)  
- **Shiny Server** (for R/Shiny applications that link back to JBrowse and BLAST)  
- **Dependencies** (Samtools, BLAST+, Tabix, R, Bioconductor, etc.)

All tools are integrated with genomic data pulled from a GitHub release tarball.

### Installing the Container

```bash
# Clone the repository
git clone https://github.com/kallistaconsulting/genomic_resources_megaselia.git
cd genomic_resources_megaselia

# Build and run the container
sudo bash setup.sh
```

This runs a docker build command (docker build -t genome_browser .) and a docker run command.  The docker run command creates an environmental variable in the docker that contains the host IP (necessary for SequenceServer2.0 link backs to JBrowse) and links ports from the container to the host machine.

Note: this will take about 30m to install, mainly due to installation of R packages.  Testing indicated 40Gb root directory was sufficient, 20Gb was not.

From here, you can run any of the tools from a web browser with the proper links:
* IP:3000?config=config.json  → JBrowse2 instance
* IP:3838/freeCount/apps/DA/ → edgeR differential expression applications
* IP:3838/freeCount/apps/FA/ → topGO and GSEA functional enrichment applications
* IP:3838/crisprFinder → views pre-profiled transcriptome to aid in initial design of sgRNA
* IP:3838/crisprViewer → views pre-created crispr sgRNA primer design tables
* IP:4567 → SequenceServer2.0 instance with blast databases and JBrowse2 link backs

## 2) Webpage set up (optional but recommended)
Tools are integrated into a pre-configured Drupal website that is customizable as any Drupal site, but organizes the tools and resources in point and click interface to make it easy to remember.  There are additional items in the website such as pages for downloading the references used, publications associated with the site, etc.  An example is currently available at: http://149.165.151.125/home

This takes ~5m to set up.

### Installing the website
1. On the local machine:

```bash
cd genomic_resources_megaselia/drupal
```

2. Edit init.sql
This file defines your username, database name, and password.  You will want to edit this from the defaults to provide security, as the defaults are used and they are publicly known.  Change ‘drupalpass’ to any password you would like to use.  Use this password for all following passwords mentioned.

3. Run install script:
This script will setup Drupal in the local machine’s /var/www/html directory.  Drupal 9.5.11 will be installed, the business theme used for the site will be pulled, and the mysql database that hold the site information will be imported.
While installing, it will also ask you a couple of other questions.  Testing was done with:
  * there is no root password, hit enter
  * unix_socket auth Y
  * reset root password (for ease, I set it the same as step 2)
  * remove anon users Y
  * disallow root login remotely
  * remove test database Y
  * reload privilege tables now Y.

  You will then be asked to enter a password twice, use the one you set above.

``` bash
sudo bash setup.sh
```

4. You should now be able to access the website from your own IP (e.g. 149.165.151.125).
You will see a Drupal setup page, which you only have to do once.  Tested with Standard installation, and the information from the init.sql file (drupal is your database by default, drupaluser as username, and whatever you set as root password.  Save and continue, reload IP/home.
The site should come up automatically now.  All tools are linked with dynamic links, meaning the host IP does not matter.

5. For security, please IMMEDIATELY:
  * Go into the Access tab and log in as user: admin, password: megaselia.
  * Now the drupal admin menu will appear at the top of the site.  Click people, and next to admin, click edit.
  * Change your password by typing the preset password (megaselia) at the top under 'Current password', then your new password next to 'Password' and again below when prompted.  Scroll to the bottom and save.
You now have secured access to this drupal site and can customize with basic Drupal methods.

### Custom Features
* Customizable genome browser website with very minimal command line
* Runnable on any VM with docker, tested on Jetstream2 Cloud
* JBrowse links to various databases - UniProt, FlyBase, Google Scholar
* Sequence Server to JBrowse2 links
* Shiny Server that will house custom versions of packages to link back to JBrowse

### Coming soon
* Usecases and tutorials coming soon
* Links back from shiny apps to JBrowse
* Profiling for CRISPR sgRNA with links to JBrowse
* BSGenome R package for genome (very soon!)

### File Notes
* start_services.sh starts services within the container in the order they need to launch
* setup.sh, one for each step, are simply wrapper scripts to make installation easy
* drupal/nginx-drupal.conf is an NGINX configuration script to deploy drupal if desired.  This file is copied into /etc/nginx/sites-available/default
* drupal/init.sql is an initialization script for the drupal site
* drupal/drupal-db.sql holds the pre-made drupal site
* SequenceServer Custom Links:  A links.rb file is provided in the data release, which allows custom links added to SequenceServer2.0, and within a container (running as root) it must replace the main links.rb script.  Note, this may misbehave with restarting, but I haven't narrowed that down yet to make a fix if needed.  You can always reinstall and repull the links.rb from the release if absolutely necessary.
Location: release, goes into /var/lib/gems/3.0.0/gems/sequenceserver-2.0.0/lib/sequenceserver/links.rb

## Preloaded Data Locations
* Initial genomic resources are unpacked from data release listed on github, which can be updated with new versions of the data as needed.
* Initial location: /var/www/
* Genome data moved to /jbrowse/megaselia/
* Blast databases moved to /data/blastdv/
* Shiny code moved to /srv/shiny-server
* Outside of container: /var/www/html/files has a copy genome, gff, transcripts, proteins file for download

## Quick Reference of Docker Locations and Ports

| Component        | Port | Path (inside 'c'ontainer or 'l'ocal) | Description                                                  |
|------------------|------|------------------------------------|--------------------------------------------------------------|
| Shiny Server     | 3838 | /srv/shiny-server/ (c)             | Includes apps: freeCount, crisprFinder, crisprViewer         |
| JBrowse 2        | 3000 | /jbrowse/megaselia/  (c)             | Preloaded with indexed Megaselia genome and GFF                |
| SequenceServer   | 4567 | /data/blastdb/     (c)             | BLAST databases for Megaselia                                  |
| BLAST+ Tools     | —    | /usr/local/bin/    (c)             | Version 2.16.0+, available in $PATH                          |
| R                | —    | System-wide installation  (c)      | Includes core bioinformatics packages                        |
| NGINX + PHP      | —    | /etc/nginx/        (l)             | Dependencies for Drupal                                      |
| Drupal           | 80   | /var/www/html/     (l)             | Drupal-ready configuration                                   |

## Troubleshooting
* If NGINX returns 502 errors:
  * try restarting php, mariadb, then nginx on command line
  * check php version - ubuntu 22.04 wants 8.1, ubuntu 24.04 wants 8.3.  Edit /etc/nginx/sites-available/nginx-drupal.conf to reflect host VM (default 24.04)
* If the drupal site is super ugly - go to Appearance -> Themes, switch to Claro, etc and then back.
* If Shiny apps do not appear:
  * Confirm the apps exist under /srv/shiny-server/
  * Check that required R packages are installed
* If gff doesn’t load in JBrowse, zoom in and hit the reload button.
