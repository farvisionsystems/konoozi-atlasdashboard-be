ARG ELIXIR_VERSION=1.14.3
ARG OTP_VERSION=25.3
ARG DEBIAN_VERSION=bullseye-20230227-slim 

# hexpm/elixir:1.14.3-erlang-25.3-debian-bullseye-20230227-slim

ARG BUILDER_IMAGE="hexpm/elixir:${ELIXIR_VERSION}-erlang-${OTP_VERSION}-debian-${DEBIAN_VERSION}"
ARG RUNNER_IMAGE="elixir"

FROM ${BUILDER_IMAGE}

# install build dependencies
RUN apt-get update -y && apt-get install -y build-essential git wget ca-certificates \
  && apt-get clean && rm -f /var/lib/apt/lists/*_*

# prepare build dir
WORKDIR /app
RUN chown nobody /app

# install hex + rebar
RUN mix local.hex --force && \
  mix local.rebar --force

# set build ENV
ENV MIX_ENV="prod"

# install mix dependencies
COPY mix.exs mix.lock ./
RUN mix deps.get --only $MIX_ENV
RUN mkdir config

COPY config/config.exs config/${MIX_ENV}.exs config/
RUN mix deps.compile

COPY entrypoint.sh ./

COPY priv priv

COPY lib lib

COPY assets assets

# compile assets
RUN mix assets.deploy

# Compile the release
RUN mix compile

# Changes to config/runtime.exs don't require recompiling the code
COPY config/runtime.exs config/

RUN mix phx.gen.release --docker

# COPY rel rel
RUN mix release

RUN mkdir -p /app/_build/prod/rel/atlas/bin/uploads
RUN ln -s /app/_build/prod/rel/atlas/bin/uploads /app/uploads

RUN chmod +x /app/entrypoint.sh

EXPOSE 4000

ENTRYPOINT ["/app/entrypoint.sh"]
