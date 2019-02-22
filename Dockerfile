FROM gapsystem/gap-docker

MAINTAINER Alexander Konovalov <alexander.konovalov@st-andrews.ac.uk>

RUN rm -rf $HOME/gap/inst/gap-4.10.0/pkg/JupyterKernel-*

COPY --chown=1000:1000 . $HOME/gap/inst/gap-4.10.0/pkg/JupyterKernel

RUN cd /home/gap/inst/gap-4.10.0/pkg/JupyterKernel \
    && python3 setup.py install --user

ENV PATH /home/gap/inst/gap-4.10.0/pkg/JupyterKernel/bin:${PATH}

USER gap

WORKDIR $HOME/inst/gap-4.10.0/pkg/JupyterKernel/demos
