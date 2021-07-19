FROM gapsystem/gap-docker

MAINTAINER Alexander Konovalov <alexander.konovalov@st-andrews.ac.uk>

# Update version number each time after gap-docker container is updated
ENV GAP_VERSION 4.11.1

# Remove previous JupyterKernel installation, copy this repository and make new install

RUN cd /home/gap/inst/gap-${GAP_VERSION}/pkg/ \
    && rm -rf JupyterKernel \
    && wget https://github.com/gap-packages/JupyterKernel/archive/master.zip \
    && unzip -q master.zip \
    && rm master.zip \
    && mv JupyterKernel-master JupyterKernel \
    && cd JupyterKernel \
    && pip3 install . --user

USER gap

WORKDIR /home/gap/inst/gap-${GAP_VERSION}/pkg/JupyterKernel/demos
