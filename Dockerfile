FROM ubuntu:latest

RUN apt-get update \
    && apt-get install -y openjdk-17-jdk \
    && apt-get install -y wget \
    && apt-get install -y curl \
    && apt-get install zip unzip

COPY pipe /
COPY LICENSE.txt pipe.yml README.md /

RUN wget --no-verbose -P / https://bitbucket.org/bitbucketpipelines/bitbucket-pipes-toolkit-bash/raw/0.6.0/common.sh

RUN chmod a+x /*.sh

ENTRYPOINT ["/pipe.sh"]