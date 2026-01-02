defmodule Atlas.Repo.Migrations.CreateReport do
  use Ecto.Migration

  def change do
    # Create enum types
    execute """
    CREATE TYPE sample_interval AS ENUM (
      'hour_1', 'hour_2', 'hour_4', 'hour_6', 'hour_12', 'hour_24'
    )
    """, "DROP TYPE sample_interval"

    execute """
    CREATE TYPE run_interval AS ENUM (
      'daily', 'weekly', 'monthly'
    )
    """, "DROP TYPE run_interval"

    execute """
    CREATE TYPE run_now_duration AS ENUM (
      'day', 'week', 'month', 'custom'
    )
    """, "DROP TYPE run_now_duration"

    execute """
    CREATE TYPE agg_function AS ENUM (
      'first', 'min', 'ave', 'max', 'min_ave_max'
    )
    """, "DROP TYPE agg_function"

    execute """
    CREATE TYPE distribution_type AS ENUM (
      'all_users', 'specific_users', 'manual_email_only', 'no_distribution'
    )
    """, "DROP TYPE distribution_type"

    create table(:reports, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :slug, :string, null: false
      add :display_name, :string, null: false
      add :active_status, :boolean, default: false
      add :sample_interval, :sample_interval
      add :run_interval, :run_interval
      add :run_now_duration, :run_now_duration
      add :agg_function, :agg_function
      add :distribution, :distribution_type
      add :organization_id, references(:organizations, on_delete: :nothing), null: false
      add :is_delete, :boolean, default: false
      add :last_run_epoch, :integer
      add :created_by, references(:users, on_delete: :nothing), null: false

      timestamps()
    end

    # Indexes
    create unique_index(:reports, [:slug])
    create index(:reports, [:organization_id])
    create index(:reports, [:created_by])
    create index(:reports, [:active_status])
    create index(:reports, [:is_delete])

    # Create reports_distribution table for managing distribution settings
    create table(:reports_distribution, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :report_id, references(:reports, type: :uuid, on_delete: :delete_all), null: false
      add :contact_type, :integer # 0 for user_uid, 1 for email_address
      add :contact_value, :string # Can store either user_uid or email address

      timestamps()
    end

    create index(:reports_distribution, [:report_id])
    create index(:reports_distribution, [:contact_type])
  end
end
