import Config

config :speedtest,
  key: "297aae72",
  threads: nil,
  include: nil,
  exclude: nil

if File.exists?("config/#{config_env()}.exs") do
  import_config "#{config_env()}.exs"
end
