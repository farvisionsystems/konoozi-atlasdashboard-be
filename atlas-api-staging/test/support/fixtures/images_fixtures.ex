defmodule Atlas.ImagesFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Atlas
  """

  @doc """
  Generate a image.
  """
  def image_fixture(attrs \\ %{}) do
    {:ok, image} =
      attrs
      |> Enum.into(%{
        image: "some image"
      })
      |> Atlas.Images.create_image()

    image
  end
end
