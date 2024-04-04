FROM openjdk:11

RUN apt-get update && apt-get install -y --no-install-recommends bash curl

COPY pipe /
COPY LICENSE.txt pipe.yml README.md /

RUN wget --no-verbose -P / https://bitbucket.org/bitbucketpipelines/bitbucket-pipes-toolkit-bash/raw/0.6.0/common.sh

RUN chmod a+x /*.sh

ENTRYPOINT ["/pipe.sh"]