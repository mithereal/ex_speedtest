defmodule Speedtest.HTTP do
  @moduledoc """
  Behaviour for HTTP requests made by Speedtest, enabling clean mocking in tests.
  """

  @type headers :: [{String.t(), String.t()}]
  @type response :: %{status_code: pos_integer(), headers: headers(), body: binary()}

  @callback get(url :: String.t(), headers(), opts :: keyword()) ::
              {:ok, response()} | {:error, term()}

  @callback post(url :: String.t(), body :: iodata(), headers(), opts :: keyword()) ::
              {:ok, response()} | {:error, term()}

  @doc """
  Returns the configured HTTP client implementation (defaults to `Speedtest.HTTP.HTTPoison`).
  """
  @spec client() :: module()
  def client do
    Application.get_env(:speedtest, :http_client, Speedtest.HTTP.HTTPoison)
  end
end

defmodule Speedtest.HTTP.HTTPoison do
  @moduledoc """
  Default `Speedtest.HTTP` adapter backed by `HTTPoison`.
  """

  @behaviour Speedtest.HTTP

  @impl true
  def get(url, headers, opts) do
    case HTTPoison.get(url, headers, opts) do
      {:ok, %HTTPoison.Response{status_code: code, headers: resp_headers, body: body}} ->
        {:ok, %{status_code: code, headers: resp_headers, body: body}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @impl true
  def post(url, body, headers, opts) do
    case HTTPoison.post(url, body, headers, opts) do
      {:ok, %HTTPoison.Response{status_code: code, headers: resp_headers, body: body}} ->
        {:ok, %{status_code: code, headers: resp_headers, body: body}}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
