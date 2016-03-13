FROM fpco/stack-build:lts-4.2

RUN apt-get update && apt-get install -y \
    git \
    libpq-dev

ENV FEATURE_CREATURE_DIR=/usr/share/feature-creature
ENV PATH $FEATURE_CREATURE_DIR:$PATH

RUN mkdir -p $FEATURE_CREATURE_DIR

WORKDIR $FEATURE_CREATURE_DIR

COPY .stack-work/docker/_home/.local/bin/ .

RUN /bin/echo $PATH
RUN /bin/echo $(pwd)

CMD /bin/echo $PATH
