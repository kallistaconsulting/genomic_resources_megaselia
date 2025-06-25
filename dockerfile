FROM ubuntu:22.04

LABEL maintainer="sheri.anne.sanders@gmail.com"
ENV DEBIAN_FRONTEND=noninteractive

# Install system packages
RUN apt-get update && apt-get install -y \
    curl wget gnupg build-essential git nano \
    python3 python3-pip ruby-full \
    openjdk-11-jre-headless samtools tabix \
    libssl-dev libcurl4-openssl-dev libxml2-dev zlib1g-dev \
    && apt-get clean

# Install Node.js 18
RUN curl -fsSL https://deb.nodesource.com/setup_18.x | bash - && \
    apt-get install -y nodejs

# Install BLAST+
RUN wget ftp://ftp.ncbi.nlm.nih.gov/blast/executables/blast+/LATEST/ncbi-blast-2.16.0+-x64-linux.tar.gz && \
    tar -xzf ncbi-blast-2.16.0+-x64-linux.tar.gz && \
    cp ncbi-blast-2.16.0+/bin/* /usr/local/bin/ && \
    rm -rf ncbi-blast-2.16.0+ ncbi-blast-2.16.0+-x64-linux.tar.gz

# Install SequenceServer
RUN gem install sequenceserver

# Install JBrowse 2 CLI
RUN npm install -g @jbrowse/cli http-server && \
    mkdir /jbrowse && jbrowse create /jbrowse

# Install R 4.3 from CRAN using keyring (Ubuntu 22.04 compatible)
RUN apt-get update && apt-get install -y software-properties-common dirmngr gnupg apt-transport-https ca-certificates curl && \
    curl -fsSL https://cloud.r-project.org/bin/linux/ubuntu/marutter_pubkey.asc | gpg --dearmor -o /usr/share/keyrings/cran-archive-keyring.gpg && \
    echo "deb [signed-by=/usr/share/keyrings/cran-archive-keyring.gpg] https://cloud.r-project.org/bin/linux/ubuntu jammy-cran40/" > /etc/apt/sources.list.d/cran.list && \
    apt-get update && apt-get install -y r-base

RUN apt-get update && apt-get install -y r-base gdebi-core wget && \
    R -e "install.packages('shiny', repos='https://cloud.r-project.org/')" && \
    wget https://download3.rstudio.org/ubuntu-20.04/x86_64/shiny-server-1.5.23.1030-amd64.deb && \
    gdebi -n shiny-server-1.5.23.1030-amd64.deb && \
    rm shiny-server-1.5.23.1030-amd64.deb

RUN R -e "packageList <- c('BiocManager', 'shiny', 'bslib', 'shinyWidgets', 'ggplot2', 'rcartocolor', 'dplyr', 'statmod', 'pheatmap', 'ggplotify', 'tidyr', 'eulerr'); \
           biocList <- c('edgeR', 'topGO', 'Rgraphviz', 'crispRdesignR', 'seqinr', 'BSgenome'); \
           newPackages <- packageList[!(packageList %in% installed.packages()[,'Package'])]; \
           if(length(newPackages)) install.packages(newPackages, repos='https://cloud.r-project.org/'); \
           if(!'BiocManager' %in% installed.packages()[,'Package']) install.packages('BiocManager', repos='https://cloud.r-project.org/'); \
           if(length(biocList)) BiocManager::install(biocList)"

# Setup data directories
RUN mkdir -p /data/blastdb /srv/shiny-server

# Download resources for clogmia

RUN mkdir /var/www/ && \
    cd /var/www/ &&\
    #You can always download a release and import it, rather than pulling direct from github && \
    #COPY genome-resources-megaselia.tar.gz /var/www/ && \
    wget https://github.com/kallistaconsulting/genomic_resources_megaselia/releases/download/vjun242025.0/genome-resources-megaselia.tar.gz &&\
    tar xfv genome-resources-megaselia.tar.gz && \ 
    rm genome-resources-megaselia.tar.gz

# Set up genome browser
RUN mkdir /jbrowse/megaselia && \
    mv /var/www/genome-resources-megaselia/jbrowse2/* /jbrowse/megaselia
#    && \ 
#    cd /jbrowse/megaselia && \
#    jbrowse sort-gff Megaselia_vNCBI.gff3 | bgzip > Megaselia_vNCBI.sorted.gff3.gz && \ 
#    tabix Megaselia_vNCBI.sorted.gff3.gz

# Set up blast databases
RUN cd /data/blastdb/ && \
    mv /var/www/genome-resources-megaselia/blastdb/* /data/blastdb/

# Set up shiny apps
RUN cd /srv/shiny-server/ && \
    mv /var/www/genome-resources-megaselia/apps/freeCount/ /srv/shiny-server/ && \
    mv /var/www/genome-resources-megaselia/apps/crisprFinder/ /srv/shiny-server/ && \
    mv /var/www/genome-resources-megaselia/apps/crisprViewer/ /srv/shiny-server/

# Copy startup script
COPY start_services.sh /start_services.sh
RUN chmod +x /start_services.sh

# Expose necessary ports
EXPOSE 3838 3000 4567

# Default command
CMD ["/start_services.sh"]

# Set up sequence server and links.rb (has to be after it's running?)
RUN mv /var/lib/gems/3.0.0/gems/sequenceserver-2.0.0/lib/sequenceserver/links.rb /var/lib/gems/3.0.0/gems/sequenceserver-2.0.0/lib/sequenceserver/links.rb.orig &&\
    mv /var/www/genome-resources-clogmia/links.rb /var/lib/gems/3.0.0/gems/sequenceserver-2.0.0/lib/sequenceserver/links.rb
