defmodule Atlas.Repo.Migrations.AddProfileTable do
  use Ecto.Migration

  def up do
    # Create the profile table with the fields from the users table
    create table(:profiles) do
      add :agent_email, :string, null: false
      add :image_url, :string
      add :first_name, :string, null: false
      add :last_name, :string, null: false
      add :phone_number_primary, :string, null: false
      add :brokerage_name, :string, null: false
      add :brokerage_lisence_no, :string, null: false
      add :lisence_id_no, :string, null: false
      add :broker_street_address, :string
      add :broker_city, :string
      add :brokerage_state, :string
      add :brokerage_zip_code, :string
      add :is_completed, :boolean
      add :user_id, references(:users, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    # Add index for user_id
    create index(:profiles, [:user_id])

    # Remove the fields from the users table
    alter table(:users) do
      remove :first_name
      remove :image_url
      remove :last_name
      remove :phone_number_primary
      remove :brokerage_name
      remove :brokerage_lisence_no
      remove :lisence_id_no
      remove :broker_street_address
      remove :broker_city
      remove :brokerage_state
      remove :brokerage_zip_code
      remove :is_completed
    end
  end

  def down do
    # Add the fields back to the users table
    alter table(:users) do
      add :image_url, :string
      add :first_name, :string
      add :last_name, :string
      add :phone_number_primary, :string
      add :brokerage_name, :string
      add :brokerage_lisence_no, :string
      add :lisence_id_no, :string
      add :broker_street_address, :string
      add :broker_city, :string
      add :brokerage_state, :string
      add :brokerage_zip_code, :string
      add :is_completed, :boolean
    end

    # Drop the profiles table
    drop table(:profiles)
  end
end

# field :is_completed, :boolean, default: false
# field :first_name, :string
# field :last_name, :string
# field :phone_number_primary, :string
# field :agent_email, :string
# field :image_url, :string
# field :brokerage_name, :string
# field :brokerage_lisence_no, :string
# field :lisence_id_no, :string
# field :broker_street_address, :string
# field :broker_city, :string
# field :brokerage_zip_code, :string
# field :brokerage_state, :string
