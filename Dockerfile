# JupyterLab with GAP and this checkout of JupyterKernel, also used by Binder.
#   docker build -t gap-jupyter .
#   docker run --rm -p 8888:8888 gap-jupyter
# Binder needs an explicit tag; update it with each GAP image release.
ARG GAP_VERSION=4.15.1
FROM ghcr.io/gap-system/gap:${GAP_VERSION}-full
ARG GAP_VERSION

USER root
RUN apt-get update \
    && apt-get install -y --no-install-recommends python3-pip build-essential libgmp-dev \
    && rm -rf /var/lib/apt/lists/* \
    && mkdir /home/gap \
    && chown gap:gap /home/gap

# Binder runs as uid 1000, the image's "gap" user, with the repository in $HOME.
ENV HOME=/home/gap
COPY --chown=gap:gap . ${HOME}
USER gap

# The GAP release bundles an older json; build the required version first.
RUN curl -fsSL https://github.com/gap-packages/json/releases/download/v2.4.0/json-2.4.0.tar.gz \
        -o /tmp/gap-jupyter-json.tar.gz \
    && tar -xzf /tmp/gap-jupyter-json.tar.gz -C /opt/gap/gap-${GAP_VERSION}/pkg \
    && rm /tmp/gap-jupyter-json.tar.gz \
    && (cd /opt/gap/gap-${GAP_VERSION}/pkg/json-2.4.0 \
        && ./configure /opt/gap/gap-${GAP_VERSION} && make) \
    && rm -rf /opt/gap/gap-${GAP_VERSION}/pkg/jupyterkernel* \
    && ln -s ${HOME} /opt/gap/gap-${GAP_VERSION}/pkg/jupyterkernel \
    && python3 -m pip install --no-cache-dir --user "${HOME}[server]" \
    && gap -q -T -c 'if LoadPackage("JupyterKernel") <> true then QUIT_GAP(1); fi; QUIT_GAP(0);'
ENV PATH=${HOME}/.local/bin:${PATH}

WORKDIR ${HOME}/demos
EXPOSE 8888
CMD ["jupyter", "lab", "--ip=0.0.0.0", "--no-browser"]
