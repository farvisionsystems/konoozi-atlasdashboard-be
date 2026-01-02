defmodule Atlas.Repo.Migrations.AddLisenceIdNoToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :lisence_id_no, :string
    end
  end
end
