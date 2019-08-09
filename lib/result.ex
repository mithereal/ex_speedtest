defmodule Speedtest.Result do
  defstruct download: nil,
            upload: nil

  def create(data) do
    {:ok, data}
  end
end
