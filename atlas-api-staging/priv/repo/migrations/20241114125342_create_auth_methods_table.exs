defmodule Atlas.Repo.Migrations.CreateAuthMethodsTable do
  use Ecto.Migration

  def change do
    create table(:auth_methods, primary_key: false) do
      add :name, :string, primary_key: true, null: false

      timestamps()
    end

    execute("""
    INSERT INTO auth_methods (name, inserted_at, updated_at)
    VALUES
      ('google', NOW(), NOW()),
      ('email', NOW(), NOW())
    """)
  end
end
