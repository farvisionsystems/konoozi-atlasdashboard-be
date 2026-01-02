defmodule Atlas.Note do
  use Ecto.Schema
  import Ecto.Changeset
  alias Atlas.{Accounts.User, Buyer, Repo}

  schema "notes" do
    field :content, :string
    belongs_to :user, User
    belongs_to :buyer, Buyer

    timestamps(type: :utc_datetime)
  end

  def changeset(note, attrs) do
    note
    |> cast(attrs, [:content, :user_id, :buyer_id])
    |> validate_required([:content, :user_id, :buyer_id])
  end

  def delete_note_if_exists(buyer_id, user_id) do
    case Repo.get_by(__MODULE__, user_id: user_id, buyer_id: buyer_id) do
      nil ->
        {:ok, ""}

      note ->
        Repo.delete(note)
    end
  end
end
