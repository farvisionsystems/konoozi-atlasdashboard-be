defmodule Atlas.MobileNotifier do
  # Function to send push notification by userId
  def send_push_notification(user_id, title, message, subtitle, thread_data, other_user_id) do
    onesignal_url = System.get_env("ONESIGNAL_URL")
    onesignal_app_id = System.get_env("ONESIGNAL_APP_ID")
    onesignal_api_key = System.get_env("ONESIGNAL_API_KEY")

    notification = %{
      app_id: onesignal_app_id,
      filters: [
        %{"field" => "tag", "key" => "userId", "relation" => "=", "value" => user_id}
      ],
      headings: %{"en" => title},
      subtitle: %{
        "en" => subtitle
      },
      contents: %{"en" => message},
      data: %{
        click_action: "chat-details",
        chat_data: thread_data,
        other_user_id: other_user_id
      }
    }

    headers = [
      {"Content-Type", "application/json"},
      {"Authorization", "Basic #{onesignal_api_key}"}
    ]

    body = Jason.encode!(notification)

    # Send the request
    case HTTPoison.post(onesignal_url, body, headers) do
      {:ok, %HTTPoison.Response{status_code: 200, body: response_body}} ->
        IO.puts("Notification sent successfully!")
        IO.inspect(body, label: "Final Request Body (JSON)")

        IO.inspect(response_body, label: "Response Body")

      {:ok, %HTTPoison.Response{status_code: status_code, body: response_body}} ->
        IO.puts("Failed to send notification, status: #{status_code}")
        IO.inspect(response_body, label: "Response Body")

      {:error, %HTTPoison.Error{reason: reason}} ->
        IO.puts("Error sending notification:")
        IO.inspect(reason, label: "Error Reason")
    end
  end

  def send_push_notification_by_user_ids(user_ids, title, subtitle, message, buyer_card) do
    onesignal_url = System.get_env("ONESIGNAL_URL")
    onesignal_app_id = System.get_env("ONESIGNAL_APP_ID")
    onesignal_api_key = System.get_env("ONESIGNAL_API_KEY")

    # Build the filters for each user_id
    filters = build_filters_by_user_ids(user_ids)

    IO.inspect(filters, label: "User ID filters")

    # Create a local copy of buyer_card with `my_buyer` set to false
    modified_buyer_card = Map.put(buyer_card, :my_buyer, false)

    # Construct the notification payload
    notification = %{
      app_id: onesignal_app_id,
      filters: filters,
      headings: %{"en" => title},
      subtitle: %{"en" => subtitle},
      contents: %{"en" => message},
      data: %{
        click_action: "buyercard-details",
        buyer_card: modified_buyer_card
      }
    }

    # Convert the payload to JSON
    notification_json = Jason.encode!(notification)

    # Send the HTTP request
    headers = [
      {"Content-Type", "application/json"},
      {"Authorization", "Basic #{onesignal_api_key}"}
    ]

    case HTTPoison.post(onesignal_url, notification_json, headers) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        IO.inspect(notification_json, label: "Notification JSON Payload")
        IO.inspect(%{status_code: 200, body: body}, label: "Notification Response")
        {:ok, "Notification sent successfully!"}

      {:ok, %HTTPoison.Response{status_code: status_code, body: body}} ->
        IO.inspect(%{status_code: status_code, body: body}, label: "Notification Error Response")
        {:error, "Failed to send notification, status: #{status_code}"}

      {:error, %HTTPoison.Error{reason: reason}} ->
        IO.inspect(%{error: reason}, label: "Notification Request Failed")
        {:error, "HTTP request failed: #{reason}"}
    end
  end

  # Helper function to build filters for multiple user IDs
  defp build_filters_by_user_ids(user_ids) do
    user_id_filters =
      user_ids
      |> Enum.flat_map(fn user_id ->
        [
          %{"field" => "tag", "key" => "userId", "relation" => "=", "value" => user_id},
          %{"operator" => "OR"}
        ]
      end)
      # Drop the last 'OR' operator
      |> Enum.drop(-1)
  end
end
