FROM postgres:15-bullseye

# install build deps and pg_partman
RUN set -x && \
    apt-get update && \
    apt-get install -y postgresql-15-partman curl make patch python3-pip && \
    apt-get clean -y && \
    rm -r /var/lib/apt/lists/*

# install pgtap
RUN set -x && \
    tmp="$(mktemp -d)" && \
    trap "rm -rf '$tmp'" EXIT && \
    cd "$tmp" && \
    curl -fsSL https://github.com/theory/pgtap/archive/refs/tags/v1.2.0.tar.gz -o pgtap.tar.gz && \
    tar -xzf pgtap.tar.gz --strip-components 1 && \
    make install

WORKDIR /swoop/db
COPY requirements.txt .
RUN pip3 install -r requirements.txt
COPY ./src ./src
COPY README.md pyproject.toml LICENSE .
RUN pip3 install .

ENV PGDATABASE: "${PGDATABASE:-swoop}" \
    PGUSER: "${PGUSER:-postgres}"

RUN python3 -V
