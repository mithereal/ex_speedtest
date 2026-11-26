import Config

config :speedtest,
  http_client: Speedtest.HTTPMock

config :logger, level: :warning
