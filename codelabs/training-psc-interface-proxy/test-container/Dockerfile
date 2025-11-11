# https://medium.com/@albertazzir/blazing-fast-python-docker-builds-with-poetry-a78a66f5aed0

# Fetch the base image
# https://hub.docker.com/r/amd64/python/
# FROM amd64/python:3.10.12
# The builder image, used to build the virtual environment
FROM python:3.10.12-slim-bookworm

# Install pipx
RUN apt-get update && \
    apt-get install --no-install-suggests --no-install-recommends --yes pipx

# Install network tools: ping, dig, nslookup
RUN apt-get update && \
    apt-get install -y net-tools iputils-ping tcpdump dnsutils

ENV PATH="/root/.local/bin:${PATH}"
RUN pipx install poetry
RUN pipx inject poetry poetry-plugin-bundle

ENV POETRY_NO_INTERACTION=1 \
    POETRY_VIRTUALENVS_IN_PROJECT=1 \
    POETRY_VIRTUALENVS_CREATE=1 \
    POETRY_CACHE_DIR=/tmp/poetry_cache

# Set the working dir for the rest of the commands
WORKDIR /

# COPY requirements.txt .
COPY pyproject.toml .
# COPY poetry.lock .

RUN poetry install --no-root && rm -rf $POETRY_CACHE_DIR

ENV VIRTUAL_ENV=/.venv \
    PATH="/.venv/bin:$PATH"

# Copies the trainer code to the docker image.
COPY trainer /trainer

# Sets up the entry point to invoke the trainer.
ENTRYPOINT [ "poetry", "run", "python", "-m", "trainer.train" ]
