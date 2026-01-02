defmodule Atlas.Message do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query
  alias Atlas.{Thread, Repo, TimezoneAdjuster, Message}

  defimpl Jason.Encoder, for: Atlas.Message do
    def encode(message, opts) do
      Jason.Encode.map(
        %{
          id: message.id,
          content: message.content,
          sent_by: message.sent_by,
          received_by: message.received_by,
          attachements: message.attachements,
          is_read: message.is_read,
          is_deleted: message.is_deleted,
          initiated_at: message.initiated_at,
          edited_at: message.edited_at,
          is_edited: message.is_edited,
          parent_id: message.parent_id,
          inserted_at: message.inserted_at,
          updated_at: message.updated_at,
          parent_message: get_parent_message(message.parent_message)
        },
        opts
      )
    end

    def get_parent_message(nil), do: nil

    def get_parent_message(message) do
      message |> Map.from_struct() |> Map.drop([:__meta__, :parent_message, :thread, :parent_id])
    end
  end

  schema "messages" do
    field :content, :string
    field :sent_by, :integer
    field :received_by, :integer
    field :attachements, :string
    field :is_read, :boolean
    field :is_deleted, :boolean
    field :initiated_at, :utc_datetime
    field :edited_at, :utc_datetime
    field :is_edited, :boolean

    belongs_to :parent_message, Message, foreign_key: :parent_id, references: :id, type: :integer
    belongs_to :thread, Thread

    timestamps(type: :utc_datetime)
  end

  def changeset(note, attrs) do
    note
    |> cast(attrs, [
      :content,
      :sent_by,
      :received_by,
      :attachements,
      :is_read,
      :initiated_at,
      :edited_at,
      :is_edited,
      :parent_id,
      :thread_id
    ])
    |> validate_required([:content, :sent_by, :received_by, :thread_id])
  end

  def insert_new_message(thread_id, attrs) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    # timezone_offset = Map.get(attrs, "timezone_offset")

    attrs =
      attrs
      |> Map.put("thread_id", thread_id)
      |> Map.put("initiated_at", now)

    %Message{}
    |> Message.changeset(attrs)
    |> Repo.insert!()
    |> Repo.preload(:parent_message)
  end

  def get_all_messages(thread_id) do
    from(m in __MODULE__,
      where: m.thread_id == ^thread_id
    )
    |> Repo.all()
    |> Repo.preload(:parent_message)
  end

  def get_user_message_ids_via_thread(user_id, message_ids) do
    from(m in Message,
      join: t in Thread,
      on: m.thread_id == t.id,
      join: tu in "threads_users",
      on: t.id == tu.thread_id,
      where: tu.user_id == ^user_id and m.id in ^message_ids,
      select: m.id
    )
    |> Repo.all()
  end

  def delete_messages(message_ids) do
    messages = Enum.map(message_ids, &Repo.get(__MODULE__, &1))

    Enum.map(messages, fn message ->
      changeset = Ecto.Changeset.change(message, is_deleted: true)

      Repo.update!(changeset)
      |> Repo.preload(:parent_message)
    end)
  end

  def get_messages(thread_id) do
    from(m in Message, where: m.thread_id == ^thread_id, order_by: m.inserted_at)
    |> Repo.all()
    |> Repo.preload(:parent_message)
  end

  def belongs_to_user?(user_id, message_id) do
    from(m in Message, where: m.id == ^message_id and m.sent_by == ^user_id) |> Repo.exists?()
  end

  def edit_message(message_id, content) do
    message = Repo.get(Message, message_id)
    changeset = Ecto.Changeset.change(message, content: content)

    Repo.update!(changeset)
    |> Repo.preload(:parent_message)
  end
end
