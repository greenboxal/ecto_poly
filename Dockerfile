FROM elixir:1.7

ADD . /app
WORKDIR /app

RUN mix local.hex --force && \
  mix local.rebar --force && \
  mix deps.get

CMD ["mix", "test"]

