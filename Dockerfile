FROM gapsystem/gap-docker-master

MAINTAINER Alexander Konovalov <alexander.konovalov@st-andrews.ac.uk>

RUN cd /home/gap/inst/gap-master/pkg/ \
    && rm -rf JupyterKernel-* \
    && wget https://github.com/gap-packages/JupyterKernel/archive/master.zip \
    && unzip -q master.zip \
    && rm master.zip \
    && mv JupyterKernel-master JupyterKernel \
    && cd JupyterKernel \
    && python3 setup.py install --user

ENV PATH /home/gap/inst/gap-master/pkg/JupyterKernel/bin:${PATH}

USER gap

WORKDIR /home/gap
