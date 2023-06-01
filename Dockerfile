# build python venv for inclusion into image
FROM postgres:15-bullseye as APP
RUN apt-get update && apt-get install -y git python3-venv
WORKDIR /opt/swoop/db
RUN python3 -m venv --copies swoop-db-venv
COPY requirements.txt .
RUN ./swoop-db-venv/bin/pip install -r requirements.txt
RUN --mount=source=.git,target=.git,type=bind git clone . clone
RUN ./swoop-db-venv/bin/pip install ./clone

FROM postgres:15-bullseye
# install build deps and pg_partman
RUN set -x && \
    apt-get update && \
    apt-get install -y postgresql-15-partman curl make patch && \
    apt-get clean -y && \
    rm -r /var/lib/apt/lists/*

# install pgtap
ARG PGTAP_VERSION=1.2.0
RUN set -x && \
    tmp="$(mktemp -d)" && \
    trap "rm -rf '$tmp'" EXIT && \
    cd "$tmp" && \
    curl -fsSL https://github.com/theory/pgtap/archive/refs/tags/v${PGTAP_VERSION}.tar.gz \
        -o pgtap.tar.gz && \
    tar -xzf pgtap.tar.gz --strip-components 1 && \
    make install

ENV PGDATABASE: "${PGDATABASE:-swoop}" \
    PGUSER: "${PGUSER:-postgres}"

# copy the python venv into this output image and add it's bin to the path
COPY --from=APP /opt/swoop/db/swoop-db-venv /opt/swoop/db/swoop-db-venv
ENV PATH=/opt/swoop/db/swoop-db-venv/bin:$PATH
