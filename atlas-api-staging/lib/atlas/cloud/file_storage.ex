defmodule Atlas.Cloud.FileStorage do
  @moduledoc """
  Manages URL signing to store photos on AWS S3
  """

  @callback upload_stream(String.t(), String.t()) :: {:error, any} | {:ok, any}
  @callback download_stream(String.t(), String.t()) :: {:error, any} | {:ok, any}
  @callback get(String.t()) :: {:error, any} | {:ok, any}
  @callback delete(String.t()) :: {:error, any} | {:ok, any}
  @callback pre_signed_url!(String.t(), atom()) :: String.t()

  def download_stream(pick_path, dest_path), do: impl().download_stream(pick_path, dest_path)

  def upload_stream(pick_path, dest_path, opts \\ []),
    do: impl().upload_stream(pick_path, dest_path, opts)

  def get(path), do: impl().get(path)
  def delete(path), do: impl().delete(path)

  def pre_signed_url!(path, method \\ :get)
  def pre_signed_url!("http://xsgames" <> url, :get), do: "http://xsgames" <> url
  def pre_signed_url!(path, method), do: impl().pre_signed_url!(path, method)

  defp impl, do: Application.get_env(:atlas, :storage_service)
end
