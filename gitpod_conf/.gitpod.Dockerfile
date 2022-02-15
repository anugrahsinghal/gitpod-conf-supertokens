FROM gitpod/workspace-full


#region INSTALL POSTGRES
USER gitpod

# Dazzle does not rebuild a layer until one of its lines are changed. Increase this counter to rebuild this layer.
ENV TRIGGER_REBUILD=2
ENV PGWORKSPACE="/workspace/.pgsql"
ENV PGDATA="$PGWORKSPACE/data"
RUN sudo mkdir -p $PGDATA
RUN sudo chown gitpod $PGWORKSPACE -R

# Install PostgreSQL
RUN sudo install-packages postgresql-12 postgresql-contrib-12

# Setup PostgreSQL server for user gitpod
ENV PATH="/usr/lib/postgresql/12/bin:$PATH"

RUN mkdir -p ~/.pg_ctl/bin ~/.pg_ctl/sockets \
 && initdb -D $PGDATA \
 && printf '#!/bin/bash\npg_ctl -D $PGDATA -l ~/.pg_ctl/log -o "-k ~/.pg_ctl/sockets" start\n' > ~/.pg_ctl/bin/pg_start \
 && printf '#!/bin/bash\npg_ctl -D $PGDATA -l ~/.pg_ctl/log -o "-k ~/.pg_ctl/sockets" stop\n' > ~/.pg_ctl/bin/pg_stop \
 && chmod +x ~/.pg_ctl/bin/*
ENV PATH="$HOME/.pg_ctl/bin:$PATH"
ENV DATABASE_URL="postgresql://gitpod@localhost"
ENV PGHOSTADDR="127.0.0.1"
ENV PGDATABASE="postgres"

# This is a bit of a hack. At the moment we have no means of starting background
# tasks from a Dockerfile. This workaround checks, on each bashrc eval, if the
# PostgreSQL server is running, and if not starts it.
RUN printf "\n# Auto-start PostgreSQL server.\n[[ \$(pg_ctl status | grep PID) ]] || pg_start > /dev/null\n" >> /home/gitpod/.bashrc.d/200-postgresql-launch
RUN chmod +x /home/gitpod/.bashrc.d/200-postgresql-launch
#endregion

#region MYSQL
USER root

# Dazzle does not rebuild a layer until one of its lines are changed. Increase this counter to rebuild this layer.
ENV TRIGGER_REBUILD=1

# Install MySQL
RUN install-packages mysql-server \
 && mkdir -p /var/run/mysqld /var/log/mysql \
 && chown -R gitpod:gitpod /etc/mysql /var/run/mysqld /var/log/mysql /var/lib/mysql /var/lib/mysql-files /var/lib/mysql-keyring /var/lib/mysql-upgrade

# Install our own MySQL config
COPY mysql_conf/mysql.cnf /etc/mysql/mysql.conf.d/mysqld.cnf

# Install default-login for MySQL clients
COPY mysql_conf/client.cnf /etc/mysql/mysql.conf.d/client.cnf

COPY mysql_conf/mysql-bashrc-launch.sh /etc/mysql/mysql-bashrc-launch.sh

USER gitpod

RUN echo "/etc/mysql/mysql-bashrc-launch.sh" >> /home/gitpod/.bashrc.d/100-mysql-launch
#endregion


#region JAVA17
ARG JAVA_VERSION

USER gitpod

# Dazzle does not rebuild a layer until one of its lines are changed. Increase this counter to rebuild this layer.
ENV TRIGGER_REBUILD=1

RUN curl -fsSL "https://get.sdkman.io" | bash \
 && bash -c ". /home/gitpod/.sdkman/bin/sdkman-init.sh \
             && sdk install java 17.fx-zulu \
             && sdk install gradle \
             && sdk install maven \
             && sdk flush archives \
             && sdk flush temp \
             && mkdir /home/gitpod/.m2 \
             && printf '<settings>\n  <localRepository>/workspace/m2-repository/</localRepository>\n</settings>\n' > /home/gitpod/.m2/settings.xml \
             && echo 'export SDKMAN_DIR=\"/home/gitpod/.sdkman\"' >> /home/gitpod/.bashrc.d/99-java \
             && echo '[[ -s \"/home/gitpod/.sdkman/bin/sdkman-init.sh\" ]] && source \"/home/gitpod/.sdkman/bin/sdkman-init.sh\"' >> /home/gitpod/.bashrc.d/99-java"
# above, we are adding the sdkman init to .bashrc (executing sdkman-init.sh does that), because one is executed on interactive shells, the other for non-interactive shells (e.g. plugin-host)
ENV GRADLE_USER_HOME=/workspace/.gradle/
#endregion

# Install custom tools, runtime, etc.
RUN brew install fzf
