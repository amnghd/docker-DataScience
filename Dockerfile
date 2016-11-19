FROM kaggle/python:latest
MAINTAINER Florian Geigl <florian.geigl@gmail.com>

# Install graph-tool
RUN apt-key update && apt-get update && \
    apt-key adv --keyserver pgp.skewed.de --recv-key 98507F25 && \
    touch /etc/apt/sources.list.d/graph-tool.list && \
    echo 'deb http://downloads.skewed.de/apt/jessie jessie main' >> /etc/apt/sources.list.d/graph-tool.list && \
    echo 'deb-src http://downloads.skewed.de/apt/jessie jessie main' >> /etc/apt/sources.list.d/graph-tool.list && \
    apt-get update && apt-get install -y --no-install-recommends python3-graph-tool && \
    ln -s /usr/lib/python3/dist-packages/graph_tool /opt/conda/lib/python3.5/site-packages/graph_tool && \
    apt-get clean && apt-get autoremove -y && rm -rf /var/lib/apt/lists/* && rm -rf /tmp/*
    
# Install other apt stuff
RUN apt-key update && apt-get update && \
    # add more packages here \
    apt-get install bash-completion vim screen htop less git mercurial subversion openssh-server \ 
        -y --no-install-recommends && \ 
    apt-get clean && apt-get autoremove -y && rm -rf /var/lib/apt/lists/* && rm -rf /tmp/*

# Setup ssh access
RUN mkdir /var/run/sshd && \
    echo 'root:root' | chpasswd && \
    sed -i 's/PermitRootLogin without-password/PermitRootLogin yes/' /etc/ssh/sshd_config && \
    sed 's@session\s*required\s*pam_loginuid.so@session optional pam_loginuid.so@g' -i /etc/pam.d/sshd
    
# Install python2.7 for conda
# add python2.7 packages here
RUN conda create -n py27 python=2.7 anaconda seaborn flake8 -y && \
    pip install influxdb && \
    conda clean -i -l -t -y
    
# Install R & packages (use apt-get r-cran-* packages or add your packages to package_install.r)
COPY package_install.r /tmp/
COPY r_defaults.txt /tmp/
#RUN apt-key adv --keyserver keys.gnupg.net --recv-key 6212B7B7931C4BB16280BA1306F90DE5381BA480 && \
#    echo "deb http://cloud.r-project.org/bin/linux/debian jessie-cran3/" >> /etc/apt/sources.list.d/r-cran.list && \
#    echo "deb http://ftp.debian.org/debian jessie-backports main" >> /etc/apt/sources.list.d/jessie-backports.list && \
#    echo "deb http://http.debian.net/debian sid main" > /etc/apt/sources.list.d/debian-unstable.list && \
#    apt-key update && apt-get update && \
#    apt-get install libpng16-16 r-base r-base-dev r-recommended r-cran-rodbc r-cran-ggplot2 r-cran-gtools r-cran-xml r-cran-getopt r-cran-plyr \#
#	r-cran-rcurl r-cran-data.table r-cran-knitr r-cran-dplyr -y --allow-unauthenticated --no-install-recommends && \
#    ldconfig && \
RUN conda install r r-base r-recommended r-ggplot2 r-gtools r-xml r-xml2 r-plyr r-rcurl \
    r-data.table r-knitr r-dplyr \
    -c bioconda -c r -c BioBuilds && \
    cat /tmp/r_defaults.txt >> /etc/R/Rprofile.site && \
    Rscript /tmp/package_install.r && \
    apt-get clean && apt-get autoremove -y && rm -rf /var/lib/apt/lists/* && rm -rf /tmp/*
      
# Install RStudio-Server & create r-user and default-credentials
RUN apt-key update && apt-get update && \
    useradd -m rstudio && \
    echo "rstudio:rstudio" | chpasswd && \
    echo 'setwd("/data/")' >> /home/rstudio/.Rprofile && \
    chown -R rstudio /home/rstudio/ && \
    chgrp -R rstudio /home/rstudio/ && \
    echo 'setwd("/data/")' >> /root/.Rprofile && \
    apt-get install -y --no-install-recommends ca-certificates file git libapparmor1 libedit2 \
        libcurl4-openssl-dev libssl-dev lsb-release psmisc python-setuptools sudo && \
    VER=$(wget --no-check-certificate -qO- https://s3.amazonaws.com/rstudio-server/current.ver) && \
    wget -q http://download2.rstudio.org/rstudio-server-${VER}-amd64.deb && \
    dpkg -i rstudio-server-${VER}-amd64.deb && \
    rm rstudio-server-*-amd64.deb && \
    ln -s /usr/lib/rstudio-server/bin/pandoc/pandoc /usr/local/bin && \
    ln -s /usr/lib/rstudio-server/bin/pandoc/pandoc-citeproc /usr/local/bin && \
    wget https://github.com/jgm/pandoc-templates/archive/1.15.0.6.tar.gz && \
    mkdir -p /opt/pandoc/templates && tar zxf 1.15.0.6.tar.gz && \
    cp -r pandoc-templates*/* /opt/pandoc/templates && rm -rf pandoc-templates* && \
    mkdir /root/.pandoc && ln -s /opt/pandoc/templates /root/.pandoc/templates && \
    apt-get clean && apt-get autoremove -y && rm -rf /var/lib/apt/lists/* && rm -rf /tmp/*
    
# Install conda python3 libs
RUN conda install pycairo cairomm libiconv jupyterlab flake8 -c conda-forge -c floriangeigl -y && \
    jupyter serverextension enable --py jupyterlab --sys-prefix && \
    conda clean -i -l -t -y

# Install pip libs
# add python3 packages here
# 	python -m textblob.download_corpora
RUN pip install tabulate ftfy pyflux cookiecutter segtok gensim textblob pandas-ply influxdb

#install julia & packages (add your packages to package_install.jl)
COPY package_install.jl /tmp/
RUN apt-get update && apt-get install julia libzmq3-dev -y --no-install-recommends && \
    julia /tmp/package_install.jl && \
    apt-get clean && apt-get autoremove -y && rm -rf /var/lib/apt/lists/* && rm -rf /tmp/*
    
# Copy Jupyter start script into the container.
COPY start-notebook.sh /usr/local/bin/
COPY start_jupyterlabs.sh /usr/local/bin/
COPY start-r-server.sh /usr/local/bin/
COPY start-ssh-server.sh /usr/local/bin/
COPY export_environment.sh /usr/local/bin/

# fix bash-completion for apt
COPY bash_completion_fix.sh /tmp/
RUN cat /tmp/bash_completion_fix.sh >> /etc/bash.bashrc && rm -rf /tmp/*

# Copy startup script into the container.
COPY startup.sh /usr/local/bin/

# Fix permissions
RUN chmod +x /usr/local/bin/start-notebook.sh && \
    chmod +x /usr/local/bin/start_jupyterlabs.sh && \
    chmod +x /usr/local/bin/startup.sh && \
    chmod +x /usr/local/bin/start-r-server.sh && \
    chmod +x /usr/local/bin/start-ssh-server.sh && \
    chmod +x /usr/local/bin/export_environment.sh
    
# Expose jupyter notebook, jupyter labs, r-studio-server and ss port.
EXPOSE 8888 8889 8787 22

# Start all scripts
CMD ["startup.sh"]
