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

# Install Latest version of BLAST+
RUN wget ftp://ftp.ncbi.nlm.nih.gov/blast/executables/blast+/LATEST/ncbi-blast-*-x64-linux.tar.gz && \
    tar -xzf ncbi-blast-*-x64-linux.tar.gz && \
    cp ncbi-blast-*/bin/* /usr/local/bin/ && \
    rm -rf ncbi-blast-*+ ncbi-blast-*+-x64-linux.tar.gz

# Install SequenceServer2.0
RUN gem install sequenceserver

# Install JBrowse 2 CLI
RUN npm install -g @jbrowse/cli http-server && \
    mkdir /jbrowse && jbrowse create /jbrowse

##########################################################################################
#  This section takes a while to install, about half of the total ~30-40m.  If you are not
#  using the shiny packages, feel free to comment this out, ending at the next comment block.  
#  One day, this will be handled better, but good enough for now :).
##########################################################################################

# Install R 4.3 from CRAN using keyring (Ubuntu 22.04 compatible)
RUN apt-get update && apt-get install -y software-properties-common dirmngr gnupg apt-transport-https ca-certificates curl && \
    curl -fsSL https://cloud.r-project.org/bin/linux/ubuntu/marutter_pubkey.asc | gpg --dearmor -o /usr/share/keyrings/cran-archive-keyring.gpg && \
    echo "deb [signed-by=/usr/share/keyrings/cran-archive-keyring.gpg] https://cloud.r-project.org/bin/linux/ubuntu jammy-cran40/" > /etc/apt/sources.list.d/cran.list && \
    apt-get update && apt-get install -y r-base

#Install R Shiny and Shiny Server
RUN apt-get update && apt-get install -y r-base gdebi-core wget && \
    R -e "install.packages('shiny', repos='https://cloud.r-project.org/')" && \
    wget https://download3.rstudio.org/ubuntu-20.04/x86_64/shiny-server-1.5.23.1030-amd64.deb && \
    gdebi -n shiny-server-1.5.23.1030-amd64.deb && \
    rm shiny-server-1.5.23.1030-amd64.deb

#Install dependency packages for pre-installed shiny apps
RUN R -e "packageList <- c('BiocManager', 'shiny', 'bslib', 'shinyWidgets', 'ggplot2', 'rcartocolor', 'dplyr', 'statmod', 'pheatmap', 'ggplotify', 'tidyr', 'eulerr'); \
           biocList <- c('edgeR', 'topGO', 'Rgraphviz', 'crispRdesignR', 'seqinr', 'BSgenome'); \
           newPackages <- packageList[!(packageList %in% installed.packages()[,'Package'])]; \
           if(length(newPackages)) install.packages(newPackages, repos='https://cloud.r-project.org/'); \
           if(!'BiocManager' %in% installed.packages()[,'Package']) install.packages('BiocManager', repos='https://cloud.r-project.org/'); \
           if(length(biocList)) BiocManager::install(biocList)"

##########################################################################################
#  End of shiny tool dependencies  
##########################################################################################

# Setup data directories
RUN mkdir -p /data/blastdb /srv/shiny-server

# Download and rename resources for Megaselia
RUN mkdir /var/www/ && \
    cd /var/www/ &&\
    wget https://github.com/kallistaconsulting/genomic_resources_megaselia/releases/download/vaug282025.0/genome-resources-megaselia.tar.gz &&\
    tar xfv genome-resources-megaselia.tar.gz && \ 
    rm genome-resources-megaselia.tar.gz && \
    cd genome-resources-megaselia/genome_files && \
    wget https://ftp.ncbi.nlm.nih.gov/genomes/all/GCA/048/544/405/GCA_048544405.1_UofC_Mab_1/GCA_048544405.1_UofC_Mab_1_genomic.gff.gz && \
    wget https://ftp.ncbi.nlm.nih.gov/genomes/all/GCA/048/544/405/GCA_048544405.1_UofC_Mab_1/GCA_048544405.1_UofC_Mab_1_genomic.fna.gz && \
    wget https://ftp.ncbi.nlm.nih.gov/genomes/all/GCA/048/544/405/GCA_048544405.1_UofC_Mab_1/GCA_048544405.1_UofC_Mab_1_cds_from_genomic.fna.gz && \
    wget https://ftp.ncbi.nlm.nih.gov/genomes/all/GCA/048/544/405/GCA_048544405.1_UofC_Mab_1/GCA_048544405.1_UofC_Mab_1_translated_cds.faa.gz && \
    for f in *gz; do gzip -d $f; done && \
    mv GCA_048544405.1_UofC_Mab_1_genomic.fna GCA_048544405.1_UofC_Mab_1_genomic.fa && \
    mv GCA_048544405.1_UofC_Mab_1_cds_from_genomic.fna GCA_048544405.1_UofC_Mab_1_cds_from_genomic.fa && \
    mv GCA_048544405.1_UofC_Mab_1_translated_cds.faa GCA_048544405.1_UofC_Mab_1_translated_cds.fa && \
    mv GCA_048544405.1_UofC_Mab_1_genomic.gff GCA_048544405.1_UofC_Mab_1_genomic.gff3

# Create and move resources for blast database construction
COPY ./scripts/makeIDmap.py /var/www/genome-resources-megaselia/blastdb

RUN cd /var/www/genomic-resources-megaselia/genome_files/ && \
    python3 /var/www/genome-resources-megaselia/blastdb/makeIDmap.py GCA_04844405.1_UofC_Mab_1_genomic.gff3 > GCA_04844405.1_UofC_Mab_1_genomic.map  && \
    cp *fa ../blastdb && \
    cp *map ../blastdb

# Format files and create blast databases set up to link between results and jbrowse.
# We format the protein and transcript files to have names that are simply the protein_id and the associated locus_id.  We can then use the locus_id to link back to jbrowse. 
COPY ./scripts/mapNames.py /var/www/genome-resources-megaselia/blastdb

RUN cd /var/www/genomic-resources-megaselia/blastdb && \
    sed -E -e 's/.*cds_/>/g' -e 's/_[0-9]+.*//g' GCA_048544405.1_UofC_Mab_1_cds_from_genomic.fa > GCA_048544405.1_UofC_Mab_1_cds_from_genomic.cleana.fa && \
    sed -E -e 's/.*prot_/>/g' -e 's/_[0-9]+.*//g' GCA_048544405.1_UofC_Mab_1_translated_cds.fa > GCA_048544405.1_UofC_Mab_1_translated_cds.cleana.fa && \
    python3 mapNames.py GCA_04844405.1_UofC_Mab_1_genomic.map GCA_04844405.1_UofC_Mab_1_translated_cds.cleana.fa > GCA_04844405.1_UofC_Mab_1_translated_cds.clean.fa && \
    python3 mapNames.py GCA_04844405.1_UofC_Mab_1_genomic.map GCA_04844405.1_UofC_Mab_1_cds_from_genomic.cleana.fa > GCA_04844405.1_UofC_Mab_1_cds_from_genomic.clean.fa && \
    makeblastdb -in GCA_048544405.1_UofC_Mab_1_genomic.fa -out Megaselia_abdita.genome.GCA_048544405.1 -dbtype nucl && \
    makeblastdb -in GCA_048544405.1_UofC_Mab_1_cds_from_genomic.clean.fa -out Megaselia_abdita.transcripts.GCA_048544405.1 -dbtype nucl && \ 
    makeblastdb -in GCA_048544405.1_UofC_Mab_1_translated_cds.clean.fa -out Megaselia_abdita.proteins.GCA_048544405.1 -dbtype prot

# Begin setting up genome browser
RUN mkdir /jbrowse/megaselia

# Populate script that adds protein product information to the gene line of 
# the gff, as it is the only one jbrowse will index.  We then use this to 
# populate database link outs.
COPY scripts/convertgff.sh /jbrowse/megaselia

# Format and index genome files. Custom script is used to add gene products to the gene-level line in
# the gff.  This is used to link out to databases by gene_id such as SCARLET
RUN mv /var/www/genome-resources-megaselia/jbrowse2/* /jbrowse/megaselia && \ 
    cd /jbrowse/megaselia && \
    cp /var/www/genome-resources-megaselia/genome_files/GCA_048544405.1_UofC_Mab_1_genomic.* /jbrowse/megaselia && \
    samtools faidx GCA_048544405.1_UofC_Mab_1_genomic.fa && \
    bash convertgff.sh <GCA_048544405.1_UofC_Mab_1_genomic.gff3 > GCA_048544405.1_UofC_Mab_1_genomic.product.gff3 && \
    jbrowse sort-gff GCA_048544405.1_UofC_Mab_1_genomic.product.gff3 | bgzip > GCA_048544405.1_UofC_Mab_1_genomic.product.sorted.gff3.gz && \ 
    tabix GCA_048544405.1_UofC_Mab_1_genomic.product.sorted.gff3.gz

# Install genome into JBrowse2, as well as annotation track
RUN cd /jbrowse/megaselia && \
    jbrowse add-assembly GCA_048544405.1_UofC_Mab_1_genomic.fa --load copy --out /jbrowse/megaselia && \
    jbrowse add-track GCA_048544405.1_UofC_Mab_1_genomic.product.sorted.gff3.gz --load inPlace --assemblyNames GCA_048544405.1_UofC_Mab_1_genomic && \
    jbrowse text-index --attributes="locus_tag" --assemblies=GCA_048544405.1_UofC_Mab_1_genomic

#Add in the json code for database link outs on the feature cards. This has to go into config.json after it is created with the new genome reference.
RUN cd /jbrowse/megaselia && \
    sed -i '/"name": "GCA_048544405.1_UofC_Mab_1_genomic.product.sorted.gff3"/c\
    "name": "GCA_048544405.1_UofC_Mab_1_genomic.product.sorted.gff3",\
    "formatDetails": {\
    "feature": "jexl:{name:\x27<a href=https://www.ncbi.nlm.nih.gov/gene/?term=\x27+feature.product+\x27>\x27+feature.name+\x27</a>\x27,type:undefined , uniprot:\x27<a href=https://www.uniprot.org/uniprotkb?query=\x27+feature.product+\x27>\x27+feature.product+\x27</a>\x27,flybase:\x27<a href=https://flybase.org/search/symbol/FBal/\x27+feature.product+\x27>\x27+feature.product+\x27</a>\x27,note:undefined,descriptions:undefine,pubs:\x27<a href=https://scholar.google.com/scholar?q=\x27+feature.product+\x27>\x27+feature.product+\x27</a>\x27 }"\
     },' config.json

# Put the blast databases in place
RUN cd /data/blastdb/ && \
    mv /var/www/genome-resources-megaselia/blastdb/* /data/blastdb/

# Populate shiny apps (require dependencies to run, but this will not fail 
# if you mute the above R dependencies for time.
RUN mv /var/www/genome-resources-megaselia/apps/freeCount/ /srv/shiny-server/ && \
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
    mv /var/www/genome-resources-megaselia/links.rb /var/lib/gems/3.0.0/gems/sequenceserver-2.0.0/lib/sequenceserver/links.rb
