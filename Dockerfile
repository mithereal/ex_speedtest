# --- Build Stage ---
FROM hexpm/elixir:1.17.3-erlang-27.1.2-alpine-3.20.3 AS build

RUN apk add --no-cache build-base git

WORKDIR /app

ENV MIX_ENV=prod

RUN mix local.hex --force && \
    mix local.rebar --force

COPY mix.exs mix.lock ./
RUN mix deps.get --only $MIX_ENV
RUN mkdir config
COPY config/config.exs config/
RUN mix deps.compile

COPY lib lib
RUN mix compile
RUN mix release

# --- Runtime Stage ---
FROM alpine:3.20.3 AS runtime

# Include iputils-ping so Speedtest.Ping works with both :http and :icmp modes,
# plus ca-certificates and libstdc++/ncurses required by the BEAM VM
RUN apk add --no-cache \
    ca-certificates \
    iputils-ping \
    libgcc \
    libstdc++ \
    ncurses-libs \
    openssl

WORKDIR /app

# Run as a non-root user
RUN adduser -D -h /app appuser && chown -R appuser:appuser /app
USER appuser

COPY --from=build --chown=appuser:appuser /app/_build/prod/rel/speedtest ./

# Run a single speedtest by default (override CMD for IEx or custom scripts)
CMD ["bin/speedtest", "eval", "IO.inspect(Speedtest.run())"]
