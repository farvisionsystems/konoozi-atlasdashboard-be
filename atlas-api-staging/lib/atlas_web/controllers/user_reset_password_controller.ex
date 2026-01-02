defmodule AtlasWeb.UserResetPasswordController do
  use AtlasWeb, :controller

  alias Atlas.Accounts

  def verify_otp_and_email(conn, %{"email" => email, "otp" => otp}) do
    downcased_email = String.downcase(email)

    # Check if OTP is a 6-digit integer
    if String.match?(otp, ~r/^\d{6}$/) do
      with user <- Accounts.get_user_by_email(downcased_email),
           true <- Accounts.verify_otp(user.id, otp, "reset_password_request"),
           {:ok, %Accounts.UserToken{}} <-
             Accounts.update_otp_status(user.id, otp, "reset_password_request") do
        message = %{title: nil, body: "OTP matched successfully"}

        render(conn, "reset.json", %{message: message})
      else
        _ ->
          conn
          |> put_status(:bad_request)
          |> render("error.json", %{error: "OTP does not match"})
      end
    else
      conn
      |> put_status(:bad_request)
      |> render("error.json", %{error: "OTP must be a 6-digit number"})
    end
  end

  def create(conn, %{"email" => email}) do
    downcased_email = String.downcase(email)

    if user = Accounts.get_user_by_email(downcased_email) do
      Accounts.delete_old_otp_if_exists(user)
      otp = Accounts.deliver_user_reset_password_instructions(user)

      message = %{title: nil, body: "Email with OTP sent"}

      render(conn, "reset.json", %{otp: %{otp: otp}, message: message})
    else
      conn
      |> put_status(:bad_request)
      |> render("error.json", %{error: "Email don't exists, please signup for your account"})
    end
  end

  # Do not log in the user after reset password to avoid a
  # leaked token giving the user access to the account.
  def update(conn, %{"email" => email, "password" => _password} = attrs) do
    with user <- Accounts.get_user_by_email(email),
         true <- Accounts.verify_otp_status(user.id, "verified"),
         {:ok, _} <- Accounts.reset_user_password(user, attrs),
         _ <- Accounts.delete_old_otp_if_exists(user) do
      message = %{title: nil, body: "Password Updated Successfully"}

      conn
      |> render("reset.json", %{message: message})
    else
      error ->
        case error do
          {:error, %Ecto.Changeset{} = changeset} ->
            error = translate_errors(changeset)

            conn
            |> put_status(:bad_request)
            |> render("error.json", error: error)

          _ ->
            conn
            |> put_status(:bad_request)
            |> render("error.json", %{error: "OTP wasn't verified"})
        end
    end
  end

  # Swagger Implementations
  swagger_path :verify_otp_and_email do
    post("/users/reset_password/verify_token")
    summary("Verify otp sent to email")

    description("Verify otp sent to email by passing otp and email")

    produces("application/json")
    security([%{Bearer: []}])

    parameters do
      body(:body, Schema.ref(:VerifyOTP), "User verifies otp by passing email and otp",
        required: true
      )
    end

    response(200, "OTP matched successfully")
  end

  swagger_path :update do
    put("/users/reset_password")
    summary("Updates password after verification of OTP")

    description(
      "Updates password after verification of OTP by passing email and updated password"
    )

    produces("application/json")
    security([%{Bearer: []}])

    parameters do
      body(
        :body,
        Schema.ref(:UpdatePass),
        "Resets password by passing email and updated password",
        required: true
      )
    end

    response(200, "OTP matched successfully")
  end

  swagger_path :create do
    post("/users/reset_password")
    summary("User Reset Password")

    description("User resets password by passing email")

    produces("application/json")
    security([%{Bearer: []}])

    parameters do
      body(:body, Schema.ref(:UserResetPassword), "User resets password by passing email",
        required: true
      )
    end

    response(200, "Email with OTP sent")
  end

  def swagger_definitions do
    %{
      UserResetPassword:
        swagger_schema do
          title("Reset Password")
          description("Reset Password")

          properties do
            email(:string, "User email for resetting password")
          end

          example(%{
            email: "admin@admin.com"
          })
        end,
      VerifyOTP:
        swagger_schema do
          title("Verify OTP")
          description("Verify OTP")

          properties do
            email(:string, "User email for resetting password")
            otp(:integer, "OTP sent to users email")
          end

          example(%{
            email: "admin@admin.com",
            otp: 123_456
          })
        end,
      UpdatePass:
        swagger_schema do
          title("Resets password")
          description("Resets password after validating otp and updates new password")

          properties do
            email(:string, "User email for resetting password")
            password(:integer, "Updated password")
          end

          example(%{
            email: "admin@admin.com",
            password: "password@123"
          })
        end
    }
  end
end
