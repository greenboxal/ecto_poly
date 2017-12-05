FROM elixir:1.5

ADD . /app
WORKDIR /app

RUN mix local.hex --force && \
  mix local.rebar --force && \
  mix deps.get

CMD ["mix", "test"]

