FROM debian:11

###############################################
# ARG
###############################################
ARG adminPass=12345
ARG mysqlPass=12345
ARG pythonVersion=python3.10
ARG appBranch=version-14

###############################################
# ENV
###############################################
# user pass
ENV systemUser=frappe
# locales
ENV LANGUAGE=en_US \
    LANG=en_US.UTF-8 \
    LC_ALL=en_US.UTF-8
# prerequisite version
ENV mariadbVersion=10.5 \
    nodejsVersion=16.x
# frappe
ENV benchPath=bench-repo \
    benchFolderName=bench \
    benchRepo="https://github.com/frappe/bench" \
    # Hot-fix: master branch didn't get jinja version bump and causing the error
    # https://github.com/frappe/bench/pull/1270
    benchBranch=v5.x \
    frappeRepo="https://github.com/frappe/frappe" \
    erpnextRepo="https://github.com/frappe/erpnext" \
    siteName=site1.local \
    PATH="$PATH:/home/frappe/.local/bin"

###############################################
# INSTALL PREREQUISITE
###############################################
RUN apt-get -y update \
    ###############################################
    # config
    ###############################################
    && apt-get -y -q install \
    # locale
    locales locales-all \
    # [fix] "debconf: delaying package configuration, since apt-utils is not installed"
    apt-utils \
    # [fix] "debconf: unable to initialize frontend: Dialog"
    # https://github.com/moby/moby/issues/27988
    && echo "debconf debconf/frontend select Noninteractive" | debconf-set-selections \
    ###############################################
    # install
    ###############################################
    # basic tools
    && apt-get -y -q install \
    wget \
    curl \
    cron \
    sudo \
    git \
    nano \
    openssl \
    build-essential \
    zlib1g-dev \
    libncurses5-dev \
    libgdbm-dev \
    libnss3-dev \
    libssl-dev \
    libreadline-dev \
    libffi-dev \
    libsqlite3-dev \
    libbz2-dev
###############################################
# [playbook] common
###############################################
# debian_family.yml
RUN apt-get -y -q install \
    dnsmasq \
    fontconfig \
    htop \
    libcrypto++-dev \
    libfreetype6-dev \
    liblcms2-dev \
    libwebp-dev \
    libxext6 \
    libxrender1 \
    libxslt1-dev \
    libxslt1.1 \
    libffi-dev \
    ntp \
    postfix \
    screen \
    xfonts-75dpi \
    xfonts-base \
    zlib1g-dev \
    apt-transport-https \
    libsasl2-dev \
    libldap2-dev \
    libcups2-dev \
    pv
###############################################
## Python 3.10 ##
###############################################
RUN echo 'export NPROC=$(nproc)' >> ~/.bashrc
ENV NPROC $NPROC
RUN bash -i -c 'echo "Compiling python build with $NPROC threads" \
    && pushd /tmp \
    && wget https://www.python.org/ftp/python/3.10.5/Python-3.10.5.tgz \
    && tar -xf Python-3.10.5.tgz \
    && cd Python-3.10.5/ \
    && ./configure --enable-optimizations \
    && make -j $NPROC \
    && make altinstall \
    && popd \
    && rm -r /tmp/Python-3.10.5'

#debug
RUN python3.10 --version

#pip3 shortcut
RUN ln -s /usr/local/bin/pip3.10 /usr/local/bin/pip3
#debug
RUN pip3 --version

# debian.yml
## pillow prerequisites for Debian >= 10
RUN apt-get -y -q install \
    libjpeg62-turbo-dev \
    libtiff5-dev \
    tcl8.6-dev \
    tk8.6-dev \
    ## pdf prerequisites debian
    && apt-get -y -q install \
    libssl-dev \
    ## Setup OpenSSL dependancy
    && pip3.10 install --upgrade pyOpenSSL
###############################################
# [playbook] mariadb
###############################################
# add repo from mariadb mirrors
# https://downloads.mariadb.org/mariadb/repositories
RUN apt-get install -y -q software-properties-common dirmngr \
    && apt-key adv --fetch-keys "https://mariadb.org/mariadb_release_signing_key.asc" \
    && add-apt-repository "deb [arch=amd64] http://nyc2.mirrors.digitalocean.com/mariadb/repo/${mariadbVersion}/debian bullseye main" \
    # mariadb.yml
    && apt-get remove -y -q --auto-remove mariadb-server \
    && apt-get update \
    && apt-get install -y -q \
    mariadb-server-10.5 \
    mariadb-client-10.5 --fix-broken --fix-missing \
    libmariadb-dev \
    psutils \
    ###############################################
    # psutil
    ###############################################
    # pip3 install --upgrade psutil \
    # pip3 install --upgrade pip setuptools \
    # python3 -m pip install --upgrade pip setuptools wheel \
    && python3.10 -m pip install -U psutil pip wheel setuptools \
    # python3 -m pip install -U --user psutil pip wheel setuptools \
    # python3 -m ensurepip --upgrade \
    # python3 -m venv env && . ./env/bin/activate \
    ###############################################
    # [playbook] wkhtmltopdf
    ###############################################
    # https://github.com/frappe/frappe_docker/blob/master/Dockerfile
    # https://gitlab.com/castlecraft/erpnext_kubernetes/blob/master/erpnext-python/Dockerfile
    && apt-get install -y -q \
    wkhtmltopdf \
    libssl-dev \
    fonts-cantarell \
    xfonts-75dpi \
    xfonts-base \
    && wget https://github.com/wkhtmltopdf/packaging/releases/download/0.12.6.1-2/wkhtmltox_0.12.6.1-2.bullseye_amd64.deb \
    && dpkg -i wkhtmltox_0.12.6.1-2.bullseye_amd64.deb \
    && rm wkhtmltox_0.12.6.1-2.bullseye_amd64.deb \
    ###############################################
    # redis
    ###############################################
    && apt-get install -y -q \
    redis-server \
    ###############################################
    # [production] supervisor
    ###############################################
    && apt-get install -y -q \
    supervisor \
    ###############################################
    # [production] nginx
    ###############################################
    && apt-get install -y -q \
    nginx
###############################################
# nodejs
###############################################
# https://github.com/nodesource/distributions
RUN curl --silent --location https://deb.nodesource.com/setup_${nodejsVersion} | bash - \
    && apt-get install -y -q nodejs \
    && sudo npm install -g -y yarn

###############################################
# Yarn install
###############################################
RUN apt remove -y cmdtest yarn \
    && apt-get purge -y cmdtest yarn \
    && curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | sudo apt-key add - \
    && echo "deb https://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list \
    && apt-get update \
    && apt-get install yarn -y

    ###############################################
    # docker production setup
    ###############################################
RUN apt-get install -y -q \
    # used for envsubst, making nginx cnf from template
    gettext-base \
    ###############################################
    # add sudoers
    ###############################################
    && adduser --disabled-password --gecos "" $systemUser \
    && usermod -aG sudo $systemUser \
    && echo "%sudo  ALL=(ALL)  NOPASSWD: ALL" > /etc/sudoers.d/sudoers \
    ###############################################
    # clean-up
    ###############################################
    && apt-get autoremove --purge -y \
    && apt-get clean -y \
    && apt-get clean all -y

###############################################
# SET USER AND WORKDIR
###############################################
USER $systemUser
WORKDIR /home/$systemUser
COPY ./ ./



###############################################
# COPY
###############################################
# mariadb config
COPY ./mariadb.cnf /etc/mysql/mariadb.cnf
RUN echo "Starting mysql/mariadb"
###############################################
# INSTALL FRAPPE
###############################################
RUN sudo chmod 644 /etc/mysql/my.cnf \
    && sudo chmod 644 /etc/mysql/mariadb.cnf

RUN sudo mkdir /var/run/mysqld \
    && sudo chown -R mysql:mysql /var/run/mysqld \
    && sudo sed -i 's/^#skip-grant-tables.*/skip-grant-tables/g' /etc/mysql/my.cnf \  
    && echo "mysqld_safe &" > /tmp/config \
    && echo "mysqladmin --silent --wait=30 ping || exit 1" >> /tmp/config \
    && echo "mysql -e 'flush privileges; GRANT ALL PRIVILEGES ON *.* TO \"root\"@\"localhost\" WITH GRANT OPTION;'" >> /tmp/config \
    && sudo mkdir -p /var/run/mysqld \
    && sudo chown mysql:mysql /var/run/mysqld \
    && sudo bash /tmp/config \
    && sudo rm -f /tmp/config \
      ### Set root password ()
    && sudo mysqladmin -u root password ${mysqlPass} \
    && sudo service mariadb stop \
    && sudo sed -i 's/^skip-grant-tables.*/#skip-grant-tables/g' /etc/mysql/my.cnf \
    && sudo service mariadb start

###############################################
# install bench
###############################################
RUN node --version && npm --version 
RUN python3.10 -m venv --system-site-packages env \
    && . ./env/bin/activate \
    && cat env/pyvenv.cfg \
    && python3.10 -m pip install --upgrade psutil pip setuptools wheel \
    && sudo pip3.10 install frappe-bench \
    && chmod o+x /home/frappe \
    && bench init $benchFolderName --verbose --frappe-path $frappeRepo --frappe-branch $appBranch --python $pythonVersion \
    #  bench init frappe-bench --verbose --frappe-branch $appBranch --python $pythonVersion
    # cd into bench folder
    && cd $benchFolderName \
    # install payments
    && bench get-app payments \
    # install erpnext
    && bench get-app erpnext $erpnextRepo --branch $appBranch \
    # delete temp file
    && sudo rm -rf /tmp/*
###############################################    
# start new site
###############################################    
RUN sudo service mariadb start && cd $benchFolderName && bench new-site $siteName \
    --mariadb-root-password $mysqlPass  \
    --admin-password $adminPass \
    && bench --site $siteName install-app erpnext \
    # compile all python file
    ## the reason for not using python3 -m compileall -q /home/$systemUser/$benchFolderName/apps
    ## is to ignore frappe/node_modules folder since it will cause syntax error
    && $pythonVersion -m compileall -q /home/$systemUser/$benchFolderName/apps/frappe/frappe \
    && $pythonVersion -m compileall -q /home/$systemUser/$benchFolderName/apps/erpnext/erpnext

###############################################
# COPY
###############################################
# production config
COPY --chown=1000:1000 production_setup/conf/frappe-docker-conf /home/$systemUser/production_config
# image entrypoint
COPY --chown=1000:1000 entrypoint.sh /usr/local/bin/entrypoint.sh

# set entrypoint permission
## prevent: docker Error response from daemon OCI runtime create failed starting container process caused "permission denied" unknown
RUN sudo chmod +x /home/$systemUser/production_config/entrypoint_prd.sh \
    && sudo chmod +x /usr/local/bin/entrypoint.sh

###############################################
# WORKDIR
###############################################
WORKDIR /home/$systemUser/$benchFolderName

###############################################
# FINALIZED
###############################################
# image entrypoint script
CMD ["/usr/local/bin/entrypoint.sh"]

# expose port
EXPOSE 8000 9000 3306
