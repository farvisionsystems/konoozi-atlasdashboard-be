defmodule Atlas.Thread do
  use Ecto.Schema
  import Ecto.Changeset
  alias Atlas.{Accounts.User, Buyer, Message}

  @derive {Jason.Encoder,
           only: [
             :id,
             :messages,
             :inserted_at,
             :updated_at
           ]}
  schema "threads" do
    many_to_many(:users, User, join_through: "threads_users", on_replace: :delete)

    belongs_to :buyer, Buyer
    has_many :messages, Message

    timestamps(type: :utc_datetime)
  end

  def changeset(note, attrs) do
    note
    |> cast(attrs, [:buyer_id])
    |> validate_required([:buyer_id])
  end
end
