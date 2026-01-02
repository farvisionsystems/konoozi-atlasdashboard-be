defmodule Atlas.Threads do
  @moduledoc """
    Buyer context.
  """

  import Ecto.Query, warn: false
  alias Atlas.Message
  alias Atlas.{Repo, Thread, Accounts.User}

  def get_by_id(id), do: Repo.get(Thread, id) |> Repo.preload(messages: [:parent_message])

  def insert_new_message(thread_id, attrs) do
    thread = get_by_id(thread_id)

    thread
    |> Thread.changeset(attrs)
    |> Repo.insert()
  end

  def maybe_mark_unarchive(user_ids, thread_id) do
    Enum.map(user_ids, &mark_chat_unarchived(to_int_if_binary(thread_id), to_int_if_binary(&1)))
  end

  def mark_chat_archived(thread_id, user_id) do
    sql = """
    UPDATE threads_users
    SET is_archived = true
    WHERE thread_id = $1 AND user_id = $2
    """

    Repo.query!(sql, [thread_id, user_id])
  end

  def mark_chat_unarchived(thread_id, user_id) do
    sql = """
    UPDATE threads_users
    SET is_archived = false
    WHERE thread_id = $1 AND user_id = $2
    """

    Repo.query!(sql, [thread_id, user_id])
  end

  def create_or_return_thread(
        user_1_id,
        user_2_id,
        buyer_id
      ) do
    user_ids = [user_1_id, user_2_id]

    case find_private_conversation_by_users_query(user_1_id, user_2_id, buyer_id) do
      nil ->
        Ecto.Multi.new()
        |> Ecto.Multi.all(:get_users, from(u in User, where: u.id in ^user_ids, select: u))
        |> Ecto.Multi.run(
          :create_conversation,
          fn _repo, %{get_users: users} ->
            Thread.changeset(%Thread{}, %{buyer_id: buyer_id})
            |> Ecto.Changeset.put_assoc(:users, users)
            |> Repo.insert()
          end
        )
        |> Repo.transaction()
        |> case do
          {:ok, %{create_conversation: thread}} ->
            thread |> Repo.preload(messages: [:parent_message])

          e ->
            e
        end

      thread ->
        thread |> Repo.preload(messages: [:parent_message])
    end
  end

  def find_private_conversation_by_users_query(first_user_id, second_user_id, buyer_id) do
    first_user_id =
      if is_binary(first_user_id), do: String.to_integer(first_user_id), else: first_user_id

    second_user_id =
      if is_binary(second_user_id), do: String.to_integer(second_user_id), else: second_user_id

    buyer_id = if is_binary(buyer_id), do: String.to_integer(buyer_id), else: buyer_id

    from(t in Thread,
      where: t.buyer_id == ^buyer_id,
      join:
        uc in subquery(
          from(uc in "threads_users",
            where: uc.user_id in ^[first_user_id, second_user_id],
            group_by: uc.thread_id,
            select: uc.thread_id,
            having: count(uc.user_id) == ^length([first_user_id, second_user_id])
          )
        ),
      on: t.id == uc.thread_id,
      group_by: t.id
    )
    |> Repo.one()
  end

  def get_all_threads(user_id) do
    from(t in Thread, where: t.user_1_id == ^user_id or t.user_2_id == ^user_id)
    |> Repo.all()
    |> Repo.preload(messages: [:parent_message])
  end

  def get_specific_thread_with_latest_message(user_id, thread_id, other_user_id) do
    user_id = to_int_if_binary(user_id)
    thread_id = to_int_if_binary(thread_id)

    query =
      from t in Thread,
        join: tu in "threads_users",
        on: tu.thread_id == t.id,
        join: u in User,
        on: tu.user_id == u.id,
        # Join for user's profile
        left_join: p in assoc(u, :profile),
        # Join for the buyer
        left_join: b in assoc(t, :buyer),
        left_join: m in assoc(t, :messages),
        where:
          u.id == ^user_id and t.id == ^thread_id and not is_nil(m.id) and not tu.is_archived,
        distinct: t.id,
        order_by: [desc: m.inserted_at],
        group_by: [t.id, b.sku, b.first_name, b.last_name, b.user_id, m.inserted_at],
        select: %{
          id: t.id,
          buyer_id: t.buyer_id,
          latest_message: max(m.id),
          latest_message_user: max(m.sent_by),
          latest_message_time: max(m.inserted_at),
          sku: b.sku,
          buyer_user_id: b.user_id,
          # Select buyer's first name from buyers table
          buyer_first_name: b.first_name,
          # Select buyer's last name from buyers table
          buyer_last_name: b.last_name,
          users:
            fragment(
              """
              SELECT json_agg(json_build_object(
                'id', u.id,
                'image_url', COALESCE(p.image_url, ''),
                'first_name', COALESCE(p.first_name, ''),
                'last_name', COALESCE(p.last_name, '')
              ))
              FROM users u
              LEFT JOIN profiles p ON p.user_id = u.id
              JOIN threads_users tu ON tu.user_id = u.id
              WHERE tu.thread_id = ?
              """,
              t.id
            )
        }

    Repo.one(query)
    |> case do
      nil ->
        nil

      thread ->
        %{
          sku: thread.sku,
          buyer_id: thread.buyer_id,
          # Get buyer's first name
          first_name: thread.buyer_first_name,
          # Get buyer's last name
          last_name: thread.buyer_last_name,
          my_buyer: thread.buyer_user_id == to_int_if_binary(user_id),
          threads: [
            %{
              id: thread.id,
              latest_message: get_message(thread.latest_message),
              new_message: thread.latest_message_user != user_id,
              user: get_user(thread.users |> List.first() |> Map.get("id")),
              time_stamp: thread.latest_message_time,
              agent_id: other_user_id,
              user_id: thread.users |> List.last() |> Map.get("id"),
              agent_image_url: thread.users |> List.first() |> Map.get("image_url"),
              user_image_url: thread.users |> List.last() |> Map.get("image_url"),
              has_new_message:
                Enum.any?(get_messages_for_user(thread.id, user_id), fn msg ->
                  msg.is_read == false or is_nil(msg.is_read)
                end)
            }
          ]
        }
    end
  end

  def get_threads_with_latest_message(user_id) do
    user_id = to_int_if_binary(user_id)

    query =
      from t in Thread,
        join: tu in "threads_users",
        on: tu.thread_id == t.id,
        join: u in User,
        on: tu.user_id == u.id,
        # Join for user's profile
        left_join: p in assoc(u, :profile),
        # Join for the buyer
        left_join: b in assoc(t, :buyer),
        left_join: m in assoc(t, :messages),
        where: u.id == ^user_id and not is_nil(m.id) and not tu.is_archived,
        distinct: t.id,
        order_by: [desc: m.inserted_at],
        group_by: [t.id, b.sku, b.first_name, b.last_name, b.user_id, m.inserted_at],
        select: %{
          id: t.id,
          buyer_id: t.buyer_id,
          latest_message: max(m.id),
          latest_message_user: max(m.sent_by),
          latest_message_time: max(m.inserted_at),
          sku: b.sku,
          buyer_user_id: b.user_id,
          # Select buyer's first name from buyers table
          buyer_first_name: b.first_name,
          # Select buyer's last name from buyers table
          buyer_last_name: b.last_name,
          users:
            fragment(
              """
              SELECT json_agg(json_build_object(
                'id', u.id,
                'image_url', COALESCE(p.image_url, ''),
                'first_name', COALESCE(p.first_name, ''),
                'last_name', COALESCE(p.last_name, '')
              ))
              FROM users u
              LEFT JOIN profiles p ON p.user_id = u.id
              JOIN threads_users tu ON tu.user_id = u.id
              WHERE tu.thread_id = ?
              """,
              t.id
            )
        }

    Repo.all(query)
    |> Enum.group_by(& &1.buyer_id)
    |> Enum.map(fn {buyer_id, threads} ->
      %{
        sku: threads |> Enum.map(& &1.sku) |> Enum.uniq() |> List.first(),
        buyer_id: buyer_id,
        # Get buyer's first name
        first_name: threads |> Enum.map(& &1.buyer_first_name) |> Enum.uniq() |> List.first(),
        # Get buyer's last name
        last_name: threads |> Enum.map(& &1.buyer_last_name) |> Enum.uniq() |> List.first(),
        my_buyer:
          Enum.any?(threads, fn t ->
            t.buyer_user_id == to_int_if_binary(user_id)
          end),
        threads:
          threads
          |> Enum.sort_by(& &1.latest_message_time, {:desc, DateTime})
          |> Enum.map(fn t ->
            {agent, user} = determine_agent_and_user(t.users, user_id)

            # Fetch all messages for the current user in this thread
            messages_for_user = get_messages_for_user(t.id, user_id)
            # Determine the readStatus by checking if any message has is_read == false
            read_status =
              Enum.any?(messages_for_user, fn msg ->
                msg.is_read == false or is_nil(msg.is_read)
              end)

            %{
              id: t.id,
              latest_message: get_message(t.latest_message),
              new_message: t.latest_message_user != user_id,
              user: get_user(agent["id"]),
              time_stamp: t.latest_message_time,
              agent_id: agent["id"],
              user_id: user["id"],
              agent_image_url: agent["image_url"],
              user_image_url: user["image_url"],
              has_new_message: read_status
            }
          end)
      }
    end)
  end

  def get_archived_threads_with_latest_message(user_id) do
    user_id = to_int_if_binary(user_id)

    query =
      from t in Thread,
        join: tu in "threads_users",
        on: tu.thread_id == t.id,
        join: u in User,
        on: tu.user_id == u.id,
        left_join: p in assoc(u, :profile),
        left_join: b in assoc(t, :buyer),
        left_join: m in assoc(t, :messages),
        where: u.id == ^user_id and not is_nil(m.id) and tu.is_archived,
        distinct: t.id,
        order_by: [desc: m.inserted_at],
        # Add b.first_name and b.last_name here
        group_by: [t.id, b.sku, b.user_id, b.first_name, b.last_name, m.inserted_at],
        select: %{
          id: t.id,
          buyer_id: t.buyer_id,
          latest_message: max(m.id),
          latest_message_user: max(m.sent_by),
          latest_message_time: max(m.inserted_at),
          sku: b.sku,
          buyer_user_id: b.user_id,
          # Select buyer's first name from buyers table
          buyer_first_name: b.first_name,
          # Select buyer's last name from buyers table
          buyer_last_name: b.last_name,
          users:
            fragment(
              """
              SELECT json_agg(json_build_object(
                'id', u.id,
                'image_url', COALESCE(p.image_url, ''),
                'first_name', COALESCE(p.first_name, ''),
                'last_name', COALESCE(p.last_name, '')
              ))
              FROM users u
              LEFT JOIN profiles p ON p.user_id = u.id
              JOIN threads_users tu ON tu.user_id = u.id
              WHERE tu.thread_id = ?
              """,
              t.id
            )
        }

    Repo.all(query)
    |> Enum.group_by(& &1.buyer_id)
    |> Enum.map(fn {buyer_id, threads} ->
      %{
        sku: threads |> Enum.map(& &1.sku) |> Enum.uniq() |> List.first(),
        buyer_id: buyer_id,
        my_buyer:
          Enum.any?(threads, fn t ->
            t.buyer_user_id == to_int_if_binary(user_id)
          end),
        # Get buyer's first name
        first_name: threads |> Enum.map(& &1.buyer_first_name) |> Enum.uniq() |> List.first(),
        # Get buyer's last name
        last_name: threads |> Enum.map(& &1.buyer_last_name) |> Enum.uniq() |> List.first(),
        threads:
          threads
          |> Enum.sort_by(& &1.latest_message_time, {:desc, DateTime})
          |> Enum.map(fn t ->
            {agent, user} = determine_agent_and_user(t.users, user_id)

            # Fetch all messages for the current user in this thread
            messages_for_user = get_messages_for_user(t.id, user_id)
            # Determine the readStatus by checking if any message has is_read == false
            read_status =
              Enum.any?(messages_for_user, fn msg ->
                msg.is_read == false or is_nil(msg.is_read)
              end)

            %{
              id: t.id,
              latest_message: get_message(t.latest_message),
              new_message: t.latest_message_user != user_id,
              user: get_user(agent["id"]),
              time_stamp: t.latest_message_time,
              agent_id: agent["id"],
              user_id: user["id"],
              agent_image_url: agent["image_url"],
              user_image_url: user["image_url"],
              has_new_message: read_status
            }
          end)
      }
    end)
  end

  defp get_message(id), do: Repo.get(Message, id) |> Repo.preload(:parent_message)

  defp determine_agent_and_user(users, given_user_id) do
    [user1, user2] = users

    if user1["id"] == given_user_id do
      {user2, user1}
    else
      {user1, user2}
    end
  end

  def update_thread_messages_status(thread_id, current_user_id) do
    thread_id = to_int_if_binary(thread_id)
    current_user_id = to_int_if_binary(current_user_id)

    from(m in Message,
      where:
        m.thread_id == ^thread_id and m.received_by == ^current_user_id and
          (is_nil(m.is_read) or m.is_read == false),
      update: [set: [is_read: true]]
    )
    # Perform the update
    |> Repo.update_all([])
  end

  defp get_user(nil), do: nil

  defp get_user(user_id) do
    Repo.get!(User, user_id) |> Repo.preload(:profile)
  end

  defp to_int_if_binary(id) do
    if is_binary(id), do: String.to_integer(id), else: id
  end

  def get_messages_for_user(thread_id, current_user_id) do
    # Ensure thread_id and current_user_id are integers
    thread_id = to_int_if_binary(thread_id)
    current_user_id = to_int_if_binary(current_user_id)

    from(m in Message,
      where: m.thread_id == ^thread_id and m.received_by == ^current_user_id,
      order_by: [asc: m.inserted_at]
    )
    |> Repo.all()
    |> Repo.preload([:parent_message])
  end
end
