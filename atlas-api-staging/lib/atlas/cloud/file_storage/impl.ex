defmodule Atlas.Cloud.FileStorage.Impl do
  @moduledoc """
  Contains methods to interact with AWS S3
  """

  alias Atlas.Cloud.FileStorage
  @behaviour FileStorage

  @impl FileStorage
  @spec upload_stream(binary, binary, keyword()) :: {:error, any} | {:ok, any}
  def upload_stream(pick_path, dest_path, opts \\ []) do
    pick_path
    |> ExAws.S3.Upload.stream_file()
    |> ExAws.S3.upload(bucket(), dest_path, opts)
    |> ExAws.request()
  end

  @impl FileStorage
  @spec download_stream(binary, :memory | binary) :: {:error, any} | {:ok, any}
  def download_stream(pick_path, dest_path) do
    bucket()
    |> ExAws.S3.download_file(pick_path, dest_path)
    |> ExAws.request()
  end

  @impl FileStorage
  @spec get(binary) :: {:error, any} | {:ok, any}
  def get(path) do
    bucket()
    |> ExAws.S3.get_object(path)
    |> ExAws.request()
  end

  @impl FileStorage
  @spec delete(binary) :: {:error, any} | {:ok, any}
  def delete(path) do
    bucket()
    |> ExAws.S3.delete_object(path)
    |> ExAws.request()
  end

  @impl FileStorage
  @spec pre_signed_url!(binary, :get | :put) :: String.t()
  def pre_signed_url!(path, method) when method in ~w(get put)a do
    {:ok, url} =
      ExAws.S3.presigned_url(
        config(),
        method,
        bucket(),
        path,
        expires_in: s3()[:expires_in],
        query_params: [{"Content-Type", "image/jpeg"}],
        virtual_host: s3()[:virtual_host]
      )

    url
  end

  defp bucket(), do: Application.get_env(:ex_aws, :bucket)

  defp config() do
    %{
      access_key_id: Application.get_env(:ex_aws, :access_key_id),
      secret_access_key: Application.get_env(:ex_aws, :secret_access_key),
      scheme: s3()[:scheme],
      region: s3()[:region],
      host: s3()[:host]
    }
  end

  defp s3(), do: Application.get_env(:ex_aws, :s3)
end
