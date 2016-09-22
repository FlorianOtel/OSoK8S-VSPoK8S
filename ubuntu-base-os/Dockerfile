FROM ubuntu:14.04
MAINTAINER BBVA Innovation <eurocloud-oneteam.group@bbva.com>
# image base based on Ubuntu with the minimal packages to build on top of this new ones

ENV PYTHON_VERSION=2.7

# Locales (avoid lots of warnings + needed for libvirtd) 
ENV LANG en_US.UTF-8  
ENV LANGUAGE en_US:en  
ENV LC_ALL en_US.UTF-8 



RUN     apt-get update && \
        apt-get install -y locales curl git openssl netcat unzip crudini gettext-base coreutils moreutils openssl tcpdump jq telnet mysql-client libxml2-dev libpq-dev libxslt-dev libffi-dev libssl-dev libmysqlclient-dev python${PYTHON_VERSION} python${PYTHON_VERSION}-dev && \
        apt-get clean && \
        rm -rf /var/lib/apt/lists/*

RUN    curl -fSL https://bootstrap.pypa.io/get-pip.py -o get-pip.py \
       && python get-pip.py \
       && pip install tox \
       && pip install mysqlclient \
       && pip install setuptools

ADD     data /

RUN     mv /etcdctl /bin/ && locale-gen en_US.UTF-8 && chown root:root /bootstrap/*.sh && chmod a+x /bootstrap/*.sh


