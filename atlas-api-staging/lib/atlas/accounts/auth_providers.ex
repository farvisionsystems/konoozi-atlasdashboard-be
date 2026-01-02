defmodule Atlas.Accounts.AuthProviders do
  @moduledoc """
  Context for Auth Modules
  """

  import Ecto.Query
  alias Atlas.{Accounts.AuthProvider, Repo}

  def create_auth_provider(attrs \\ %{}) do
    case check_if_exists?(attrs) do
      nil ->
        %AuthProvider{}
        |> AuthProvider.changeset(attrs)
        |> Repo.insert()

      %AuthProvider{} ->
        {:error, "Already exists!"}

      _ ->
        {:error, "Bad request"}
    end
  end

  def check_user_if_exists?(user_params) do
    case check_if_exists?(user_params) do
      %AuthProvider{} = auth_provider ->
        auth_provider.user

      _ ->
        nil
    end
  end

  def check_if_exists?(%{"provider" => "apple", "apple_identifier" => apple_identifier}) do
    from(ap in AuthProvider,
      join: u in assoc(ap, :user),
      where: ap.provider == "apple" and ap.apple_identifier == ^apple_identifier,
      preload: [user: u]
    )
    |> Repo.one()
  end

  def check_if_exists?(%{"provider" => provider, "email" => email}) do
    from(ap in AuthProvider,
      join: u in assoc(ap, :user),
      where: ap.provider == ^provider and ap.email == ^email,
      preload: [user: u]
    )
    |> Repo.one()
  end

  def check_if_exists?(_), do: nil
end
