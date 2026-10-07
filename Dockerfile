# JupyterLab with GAP and this checkout of JupyterKernel, also used by Binder.
#   docker build -t gap-jupyter .
#   docker run --rm -p 8888:8888 gap-jupyter
# Binder needs an explicit tag; update it with each GAP image release.
ARG GAP_VERSION=4.15.1
FROM ghcr.io/gap-system/gap:${GAP_VERSION}-full
ARG GAP_VERSION

USER root
RUN apt-get update \
    && apt-get install -y --no-install-recommends python3-pip \
    && rm -rf /var/lib/apt/lists/* \
    && mkdir /home/gap \
    && chown gap:gap /home/gap

# Binder runs as uid 1000, the image's "gap" user, with the repository in $HOME.
ENV HOME=/home/gap
COPY --chown=gap:gap . ${HOME}
USER gap

# GAP must load this checkout, not the JupyterKernel it ships.
RUN rm -rf /opt/gap/gap-${GAP_VERSION}/pkg/jupyterkernel* \
    && ln -s ${HOME} /opt/gap/gap-${GAP_VERSION}/pkg/jupyterkernel \
    && python3 -m pip install --no-cache-dir --user "${HOME}[server]"
ENV PATH=${HOME}/.local/bin:${PATH}

WORKDIR ${HOME}/demos
EXPOSE 8888
CMD ["jupyter", "lab", "--ip=0.0.0.0", "--no-browser"]
