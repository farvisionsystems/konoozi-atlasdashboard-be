defmodule Atlas.Accounts.UserNotifier do
  use Atlas.Notifiers
  require Logger
  alias Atlas.MobileNotifier

  import Bamboo.{Email}

  @frontend_base_url Application.get_env(:atlas, :frontend_base_url)
  def deliver_invite_email(invite_token, link) do
    user_name = invite_token.email |> String.split("@") |> hd()

    message = """
    <p>Hi #{user_name}, this is the link to join #{invite_token.organization.name} as a #{invite_token.role.role}</p>
      <p>#{link}</p>

    """

    email =
      new_email()
      |> to(invite_token.email)
      |> from({"Atlas Sensor Dashboard", "atlas.sensor1@gmail.com"})
      |> subject("You have been invited to #{invite_token.organization.name}")
      |> html_body(message)
      |> text_body("Welcome, !\nThank you for joining MyApp.")

    Atlas.Mailer.deliver_now(email)
    |> IO.inspect(label: "Invite Email")
  end

  # def deliver_invite_email(invite_token, link) do
  #   user_name = invite_token.email |> String.split("@") |> hd()

  #   %Bamboo.Email{
  #     subject: "Invitation to join #{invite_token.organization.name}",
  #     html_body: """
  #     <p>Hi #{user_name}, this is the link to join #{invite_token.organization.name} as a #{invite_token.role.role}</p>
  #     <p>#{link}</p>

  #     """,
  #     text_body: """
  #     Hi #{user_name}, this is the link to join #{invite_token.organization.name},
  #     #{link}

  #     """,
  #     blocked: false
  #   }
  #   |> deliver_invitation_email(invite_token.email)
  # end

  def deliver_account_deleted_email(user) do
    # Safely access the first_name from profile or default to "User"
    user_name =
      if user.profile && user.profile.first_name, do: user.profile.first_name, else: "User"

    %Bamboo.Email{
      subject: "User Account Deleted",
      html_body: """
      <p>The User Name: #{user_name}, Account Has been deleted</p>

      """,
      text_body: """
      The User Name: #{user_name}, Account Has been deleted,

      """,
      blocked: false
    }
    |> deliver_transactional_delete_email(user)
  end

  def deliver_account_deleted_email_link(user, link) do
    # Safely access the first_name from profile or default to "User"
    user_name =
      if user.profile && user.profile.first_name, do: user.profile.first_name, else: "User"

    %Bamboo.Email{
      subject: "User Account Deletion",
      html_body: """
      <p>Hi #{user_name}, this is the link to delete you account</p>
      <p>#{link}</p>

      """,
      text_body: """
      Hi #{user_name}, this is the link to delete you account,
      #{link}

      """,
      blocked: false
    }
    |> deliver_transactional_email(user)
  end

  def deliver_reset_password_instructions(user, otp) do
    first_name = (user.profile && user.profile.first_name) || "User"

    # %Bamboo.Email{
    #   subject: "Reset Your Password for Atlas",
    #   html_body: """
    #   <p>Hi #{first_name}, this is the link to otp #{otp} to reset your password </p>

    #   """,
    #   text_body: """
    #   Hi #{first_name}, this is the link to otp #{otp} to reset your password

    #   """,
    #   blocked: false
    # }
    # |> deliver_transactional_email(user)

    sendgrid_template(:password_reset_template, Name: first_name, OTP: otp)
    #    MobileNotifier.send_push_notification("27", "reset", "password has been reset")
    |> to(user.email)
    |> from(noreply_address())
    |> deliver_now()
  end

  defp deliver_transactional_email(params, user) do
    params
    |> to(user.email)
    |> from(noreply_address())
    |> deliver_now()
  end

  defp deliver_invitation_email(params, email) do
    params
    |> to(email)
    |> from(noreply_address())
    |> deliver_now()
  end

  defp deliver_transactional_delete_email(params, user) do
    params
    |> to(noreply_address())
    |> from(noreply_address())
    |> deliver_now()
  end
end
