ExUnit.start()
Mox.defmock(Speedtest.HTTPMock, for: Speedtest.HTTP)
Application.put_env(:speedtest, :http_client, Speedtest.HTTPMock)

ExUnit.start()
