FROM python:3.9-slim

RUN apt-get update && \
  apt-get install -y iputils-ping && \
  apt-get install -y wget

# Install network tools: ping, dig, nslookup
RUN apt-get update && \
    apt-get install -y net-tools tcpdump dnsutils

RUN pip install cloudml-hypertune requests kfp

# Copies the trainer code to the docker image.
COPY trainer /trainer

ENTRYPOINT ["python3", "/trainer/train.py"]
