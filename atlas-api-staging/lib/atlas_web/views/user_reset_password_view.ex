defmodule AtlasWeb.UserResetPasswordView do
  use AtlasWeb, :view

  def render("reset.json", %{otp: otp, message: message}) do
    %{data: otp, message: message}
  end

  def render("reset.json", %{message: message}), do: %{message: message}

  def render("error.json", %{error: error}) do
    %{error: %{message: error}}
  end
end
