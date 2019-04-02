FROM microsoft/mssql-tools

RUN apt-get update
RUN apt-get install -y --no-install-recommends \
		bzip2 \
		unzip \
		xz-utils \
		dos2unix

#### Install Java

# Default to UTF-8 file.encoding
ENV LANG C.UTF-8

# add a simple script that can auto-detect the appropriate JAVA_HOME value
# based on whether the JDK or only the JRE is installed
RUN { \
		echo '#!/bin/sh'; \
		echo 'set -e'; \
		echo; \
		echo 'dirname "$(dirname "$(readlink -f "$(which javac || which java)")")"'; \
	} > /usr/local/bin/docker-java-home \
	&& chmod +x /usr/local/bin/docker-java-home

# do some fancy footwork to create a JAVA_HOME that's cross-architecture-safe
RUN ln -svT "/usr/lib/jvm/java-8-openjdk-$(dpkg --print-architecture)" /docker-java-home
ENV JAVA_HOME /docker-java-home/jre

ENV JAVA_VERSION 8u181
ENV JAVA_DEBIAN_VERSION 8u181-b13-2~deb9u1

RUN set -ex; \
	\
# deal with slim variants not having man page directories (which causes "update-alternatives" to fail)
	if [ ! -d /usr/share/man/man1 ]; then \
		mkdir -p /usr/share/man/man1; \
	fi; \
	\
	apt-get install -y --no-install-recommends \
		openjdk-8-jre \
	; \
# verify that "docker-java-home" returns what we expect
	[ "$(readlink -f "$JAVA_HOME")" = "$(docker-java-home)" ]; \
	\
# update-alternatives so that future installs of other OpenJDK versions don't change /usr/bin/java
	update-alternatives --get-selections | awk -v home="$(readlink -f "$JAVA_HOME")" 'index($3, home) == 1 { $2 = "manual"; print | "update-alternatives --set-selections" }'; \
# ... and verify that it actually worked for one of the alternatives we care about
	update-alternatives --query java | grep -q 'Status: manual'

#### install liquibase
RUN mkdir -p /opt/liquibase
RUN curl -L https://github.com/liquibase/liquibase/releases/download/liquibase-parent-3.6.3/liquibase-3.6.3-bin.tar.gz \
  | tar -xzC /opt/liquibase
RUN chmod +x /opt/liquibase/liquibase
RUN ln -s /opt/liquibase/liquibase /usr/local/bin/

RUN cp /opt/liquibase/sdk/lib-sdk/slf4j-api-1.7.25.jar /opt/liquibase/lib

#### install sql drivers
RUN curl -L https://download.microsoft.com/download/0/2/A/02AAE597-3865-456C-AE7F-613F99F850A8/sqljdbc_6.0.8112.200_enu.tar.gz \
  | tar -xzC /tmp
RUN mkdir -p /opt/jdbc_drivers
RUN ln -s /tmp/sqljdbc_6.0/enu/jre8/sqljdbc42.jar /opt/jdbc_drivers
RUN ln -s /tmp/sqljdbc_6.0/enu/jre8/sqljdbc42.jar /usr/local/bin/
