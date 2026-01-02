defmodule Atlas.BuyerNeed do
  use Ecto.Schema
  import Ecto.Changeset
  alias Atlas.Buyer

  @timeline_types [values: ~w(asap three_months six_months open)a]

  @derive {Jason.Encoder,
           only: [
             :id,
             :purchase_type,
             :property_type,
             :financial_status,
             :budget_upto,
             :min_bedrooms,
             :min_bathrooms,
             :min_area,
             :buyer_id,
             :inserted_at,
             :updated_at
           ]}
  schema "buyer_needs" do
    field :purchase_type, Ecto.Enum, values: [:purchase, :lease]

    field :property_type, Ecto.Enum,
      values: [
        :single_family_house,
        :townhouse,
        :condo,
        :apartment,
        :multi_family_house,
        :land
      ]

    field :financial_status, Ecto.Enum, values: [:pre_qualified, :pre_approved, :all_cash, :n_a]

    field :budget_upto, :string
    field :min_bedrooms, :float
    field :min_bathrooms, :float
    field :min_area, :float
    belongs_to :buyer, Buyer

    timestamps(type: :utc_datetime)
  end

  def changeset(buyer, attrs) do
    buyer
    |> cast(attrs, [
      :purchase_type,
      :property_type,
      :financial_status,
      :budget_upto,
      :min_bedrooms,
      :min_bathrooms,
      :min_area,
      :buyer_id
    ])
    |> validate_required([
      :purchase_type,
      :property_type,
      :financial_status,
      :budget_upto,
      :min_bedrooms,
      :min_bathrooms,
      :min_area
    ])
  end
end
