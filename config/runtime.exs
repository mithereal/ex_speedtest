import Config

if config_env() == :prod do
  if key = System.get_env("SPEEDTEST_KEY") do
    config :speedtest, key: key
  end

  if threads = System.get_env("SPEEDTEST_THREADS") do
    config :speedtest, threads: String.to_integer(threads)
  end

  if include = System.get_env("SPEEDTEST_INCLUDE") do
    config :speedtest, include: String.split(include, ",", trim: true)
  end

  if exclude = System.get_env("SPEEDTEST_EXCLUDE") do
    config :speedtest, exclude: String.split(exclude, ",", trim: true)
  end
end
