defmodule Atlas.SmsNotifier do
  @moduledoc """
  SMS notification service for sending alarm notifications via SMS.
  Uses Twilio as the SMS provider.
  """

  require Logger

  @doc """
  Sends an SMS notification to the specified phone number.

  ## Parameters
    - phone_number: The phone number to send the SMS to (should be in E.164 format)
    - message: The message content to send
    - device_name: The name of the device that triggered the alarm (for context)

  ## Returns
    - {:ok, response} on success
    - {:error, reason} on failure
  """
  def send_sms_notification(phone_number, message, device_name) do
    # Get Twilio configuration from environment variables
    account_sid = System.get_env("TWILIO_ACCOUNT_SID")
    auth_token = System.get_env("TWILIO_AUTH_TOKEN")
    from_number = System.get_env("TWILIO_PHONE_NUMBER")

    # Validate required configuration
    if is_nil(account_sid) or is_nil(auth_token) or is_nil(from_number) do
      Logger.error("Twilio configuration missing. Please set TWILIO_ACCOUNT_SID, TWILIO_AUTH_TOKEN, and TWILIO_PHONE_NUMBER environment variables.")
      {:error, "SMS service not configured"}
    else
      # Format the phone number to E.164 format if needed
      formatted_phone = format_phone_number(phone_number)
      # Prepare the request
      url = "https://api.twilio.com/2010-04-01/Accounts/#{account_sid}/Messages.json"

      headers = [
        {"Content-Type", "application/x-www-form-urlencoded"},
        {"Authorization", "Basic #{Base.encode64("#{account_sid}:#{auth_token}")}"}
      ]

      body = URI.encode_query(%{
        "To" => formatted_phone,
        "From" => from_number,
        "Body" => "🚨 ALARM: #{device_name} - #{message}"
      })

      # Send the SMS
      case HTTPoison.post(url, body, headers) do
        {:ok, %HTTPoison.Response{status_code: 201, body: response_body}} ->
          Logger.info("SMS sent successfully to #{formatted_phone}")
          {:ok, response_body}

        {:ok, %HTTPoison.Response{status_code: status_code, body: response_body}} ->
          Logger.error("Failed to send SMS, status: #{status_code}, response: #{response_body}")
          {:error, "SMS delivery failed with status #{status_code}"}

        {:error, %HTTPoison.Error{reason: reason}} ->
          Logger.error("Error sending SMS: #{reason}")
          {:error, "SMS request failed: #{reason}"}
      end
    end
  end

  @doc """
  Adds a phone number to Twilio's verified caller list.
  This is required for sending SMS to unverified numbers in the US (A2P 10DLC compliance).

  ## Parameters
    - phone_number: The phone number to verify (should be in E.164 format)
    - friendly_name: Optional friendly name for the verified number (defaults to "Alarm System")

  ## Returns
    - {:ok, verification_sid} on success
    - {:error, reason} on failure
  """
  def add_to_verified_caller_list(phone_number, friendly_name \\ "Alarm System") do
    # Get Twilio configuration from environment variables
    account_sid = System.get_env("TWILIO_ACCOUNT_SID")
    auth_token = System.get_env("TWILIO_AUTH_TOKEN")

    # Validate required configuration
    if is_nil(account_sid) or is_nil(auth_token) do
      Logger.error("Twilio configuration missing. Please set TWILIO_ACCOUNT_SID and TWILIO_AUTH_TOKEN environment variables.")
      {:error, "Twilio service not configured"}
    else
      # Format the phone number to E.164 format if needed
      formatted_phone = format_phone_number(phone_number)

      # Validate phone number format
      if not valid_phone_number?(formatted_phone) do
        {:error, "Invalid phone number format"}
      else
        # Prepare the request to Twilio's Verified Caller ID API
        url = "https://api.twilio.com/2010-04-01/Accounts/#{account_sid}/OutgoingCallerIds.json"

        headers = [
          {"Content-Type", "application/x-www-form-urlencoded"},
          {"Authorization", "Basic #{Base.encode64("#{account_sid}:#{auth_token}")}"}
        ]

        body = URI.encode_query(%{
          "PhoneNumber" => formatted_phone,
          "FriendlyName" => friendly_name
        })

        # Add the number to verified caller list
        case HTTPoison.post(url, body, headers) do
          {:ok, %HTTPoison.Response{status_code: 201, body: response_body}} ->
            case Jason.decode(response_body) do
              {:ok, %{"sid" => verification_sid}} ->
                Logger.info("Phone number #{formatted_phone} added to verified caller list with SID: #{verification_sid}")
                {:ok, verification_sid}
              {:error, _} ->
                Logger.error("Failed to parse Twilio response for verified caller list")
                {:error, "Failed to parse Twilio response"}
            end

          {:ok, %HTTPoison.Response{status_code: 200, body: response_body}} ->
            case Jason.decode(response_body) do
              {:ok, %{"validation_code" => validation_code, "call_sid" => call_sid}} ->
                Logger.info("Phone number #{formatted_phone} added to verification queue. Validation code: #{validation_code}, Call SID: #{call_sid}")
                Logger.info("A verification call will be made to #{formatted_phone} with code: #{validation_code}")
                {:ok, call_sid}
              {:ok, %{"sid" => verification_sid}} ->
                Logger.info("Phone number #{formatted_phone} added to verified caller list with SID: #{verification_sid}")
                {:ok, verification_sid}
              {:error, _} ->
                Logger.error("Failed to parse Twilio response for verified caller list")
                {:error, "Failed to parse Twilio response"}
            end

          {:ok, %HTTPoison.Response{status_code: 400, body: response_body}} ->
            case Jason.decode(response_body) do
              {:ok, %{"message" => message}} ->
                Logger.error("Failed to add phone number to verified caller list: #{message}")
                {:error, message}
              {:error, _} ->
                Logger.error("Failed to add phone number to verified caller list: Bad request")
                {:error, "Bad request"}
            end

          {:ok, %HTTPoison.Response{status_code: status_code, body: response_body}} ->
            Logger.error("Failed to add phone number to verified caller list, status: #{status_code}, response: #{response_body}")
            {:error, "Verification failed with status #{status_code}"}

          {:error, %HTTPoison.Error{reason: reason}} ->
            Logger.error("Error adding phone number to verified caller list: #{reason}")
            {:error, "Verification request failed: #{reason}"}
        end
      end
    end
  end

  @doc """
  Submits a verification code to complete phone number verification.

  ## Parameters
    - phone_number: The phone number to verify (should be in E.164 format)
    - verification_code: The code received via phone call or SMS

  ## Returns
    - {:ok, verification_sid} on success
    - {:error, reason} on failure
  """
  def submit_verification_code(phone_number, verification_code) do
    # Get Twilio configuration from environment variables
    account_sid = System.get_env("TWILIO_ACCOUNT_SID")
    auth_token = System.get_env("TWILIO_AUTH_TOKEN")

    # Validate required configuration
    if is_nil(account_sid) or is_nil(auth_token) do
      Logger.error("Twilio configuration missing. Please set TWILIO_ACCOUNT_SID and TWILIO_AUTH_TOKEN environment variables.")
      {:error, "Twilio service not configured"}
    else
      # Format the phone number to E.164 format if needed
      formatted_phone = format_phone_number(phone_number)

      # Validate phone number format
      if not valid_phone_number?(formatted_phone) do
        {:error, "Invalid phone number format"}
      else
        # Prepare the request to Twilio's verification API
        url = "https://api.twilio.com/2010-04-01/Accounts/#{account_sid}/OutgoingCallerIds.json"

        headers = [
          {"Content-Type", "application/x-www-form-urlencoded"},
          {"Authorization", "Basic #{Base.encode64("#{account_sid}:#{auth_token}")}"}
        ]

        body = URI.encode_query(%{
          "PhoneNumber" => formatted_phone,
          "VerificationCode" => verification_code
        })

        # Submit the verification code
        case HTTPoison.post(url, body, headers) do
          {:ok, %HTTPoison.Response{status_code: 200, body: response_body}} ->
            case Jason.decode(response_body) do
              {:ok, %{"sid" => verification_sid}} ->
                Logger.info("Phone number #{formatted_phone} successfully verified with SID: #{verification_sid}")
                {:ok, verification_sid}
              {:error, _} ->
                Logger.error("Failed to parse Twilio verification response")
                {:error, "Failed to parse Twilio response"}
            end

          {:ok, %HTTPoison.Response{status_code: 400, body: response_body}} ->
            case Jason.decode(response_body) do
              {:ok, %{"message" => message}} ->
                Logger.error("Failed to verify phone number: #{message}")
                {:error, message}
              {:error, _} ->
                Logger.error("Failed to verify phone number: Bad request")
                {:error, "Bad request"}
            end

          {:ok, %HTTPoison.Response{status_code: status_code, body: response_body}} ->
            Logger.error("Failed to verify phone number, status: #{status_code}, response: #{response_body}")
            {:error, "Verification failed with status #{status_code}"}

          {:error, %HTTPoison.Error{reason: reason}} ->
            Logger.error("Error submitting verification code: #{reason}")
            {:error, "Verification request failed: #{reason}"}
        end
      end
    end
  end

  @doc """
  Checks the verification status of a phone number in Twilio's verified caller list.

  ## Parameters
    - phone_number: The phone number to check (should be in E.164 format)

  ## Returns
    - {:ok, %{status: status, friendly_name: name}} on success
    - {:error, reason} on failure
    - {:not_found} if the number is not in the verified caller list
  """
  def check_verification_status(phone_number) do
    # Get Twilio configuration from environment variables
    account_sid = System.get_env("TWILIO_ACCOUNT_SID")
    auth_token = System.get_env("TWILIO_AUTH_TOKEN")

    # Validate required configuration
    if is_nil(account_sid) or is_nil(auth_token) do
      Logger.error("Twilio configuration missing. Please set TWILIO_ACCOUNT_SID and TWILIO_AUTH_TOKEN environment variables.")
      {:error, "Twilio service not configured"}
    else
      # Format the phone number to E.164 format if needed
      formatted_phone = format_phone_number(phone_number)

      # Prepare the request to list verified caller IDs
      url = "https://api.twilio.com/2010-04-01/Accounts/#{account_sid}/OutgoingCallerIds.json"

      headers = [
        {"Authorization", "Basic #{Base.encode64("#{account_sid}:#{auth_token}")}"}
      ]

      # Get the list of verified caller IDs
      case HTTPoison.get(url, headers) do
        {:ok, %HTTPoison.Response{status_code: 200, body: response_body}} ->
          case Jason.decode(response_body) do
            {:ok, %{"outgoing_caller_ids" => caller_ids}} ->
              # Find the specific phone number in the list
              case Enum.find(caller_ids, fn caller_id ->
                caller_id["phone_number"] == formatted_phone
              end) do
                nil ->
                  {:not_found}
                caller_id ->
                  {:ok, %{
                    status: caller_id["status"],
                    friendly_name: caller_id["friendly_name"],
                    sid: caller_id["sid"]
                  }}
              end
            {:error, _} ->
              Logger.error("Failed to parse Twilio response for verification status")
              {:error, "Failed to parse Twilio response"}
          end

        {:ok, %HTTPoison.Response{status_code: status_code, body: response_body}} ->
          Logger.error("Failed to check verification status, status: #{status_code}, response: #{response_body}")
          {:error, "Status check failed with status #{status_code}"}

        {:error, %HTTPoison.Error{reason: reason}} ->
          Logger.error("Error checking verification status: #{reason}")
          {:error, "Status check request failed: #{reason}"}
      end
    end
  end

  @doc """
  Formats a phone number to E.164 format (e.g., +1234567890).
  If the number already starts with +, it's returned as is.
  If it starts with 1 and is 11 digits, it's prefixed with +.
  If it's 10 digits, it's prefixed with +1.
  """
  def format_phone_number(phone_number) when is_binary(phone_number) do
    # Remove all non-digit characters
    clean_number = String.replace(phone_number, ~r/[^\d]/, "")

    cond do
      # Already in E.164 format
      String.starts_with?(phone_number, "+") ->
        phone_number

      # 11 digits starting with 1 (US number)
      String.length(clean_number) == 11 and String.starts_with?(clean_number, "1") ->
        "+#{clean_number}"

      # 10 digits (US number)
      String.length(clean_number) == 10 ->
        "+1#{clean_number}"

      # Other formats, assume it's already correct
      true ->
        phone_number
    end
  end

  @doc """
  Validates if a phone number is in a valid format for SMS sending.
  """
  def valid_phone_number?(phone_number) when is_binary(phone_number) do
    clean_number = String.replace(phone_number, ~r/[^\d]/, "")

    # Check if it's a valid length (10-15 digits)
    String.length(clean_number) >= 10 and String.length(clean_number) <= 15
  end
end
