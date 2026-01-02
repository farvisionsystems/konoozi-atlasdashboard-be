defmodule AtlasWeb.BuyerView do
  use AtlasWeb, :view

  def render("buyers.json", %{buyers: buyers, message: message}) do
    %{data: buyers, message: message}
  end

  def render("buyers_paginated.json", %{buyers: buyers, message: message, pagination: pagination}) do
    %{
      data: buyers,
      message: message,
      pagination: %{
        total_pages: pagination.total_pages,
        total_entries: pagination.total_entries,
        current_page: pagination.page_number,
        page_size: pagination.page_size
      }
    }
  end

  def render("buyer.json", %{buyer: buyer, message: message}) do
    buyer = buyer |> Map.from_struct() |> Map.drop([:__meta__, :notes])

    %{data: buyer, message: message}
  end

  def render("buyer_with_user.json", %{buyer: buyer, message: message}) do
    buyer = buyer |> Map.from_struct() |> Map.drop([:__meta__, :notes])

    %{data: buyer, message: message}
  end

  def render("error.json", %{error: error}) do
    %{error: error}
  end

  def render("success.json", %{message: message}) do
    %{
      success: true,
      message: message
    }
  end
end
