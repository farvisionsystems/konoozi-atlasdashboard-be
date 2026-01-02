defmodule Atlas.Repo.Migrations.AddOtpToUserSessions do
  use Ecto.Migration

  def up do
    alter table(:users_tokens) do
      add :otp, :integer
    end
  end

  def down do
    alter table(:users_tokens) do
      remove :otp, :integer
    end
  end
end
