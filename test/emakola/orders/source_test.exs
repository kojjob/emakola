defmodule Emakola.Orders.SourceTest do
  use ExUnit.Case, async: true

  alias Emakola.Orders.{Order, Source}

  defp order(attrs),
    do: struct(Order, Map.merge(%{attribution: %{}, total: 100, status: :confirmed}, attrs))

  test "a pay link is a pay link before anything else" do
    assert Source.of(order(%{pay_link_id: "p", attribution: %{"utm_source" => "instagram"}})) ==
             :pay_link
  end

  test "a susu plan is susu" do
    assert Source.of(order(%{susu_plan_id: "s"})) == :susu
  end

  test "click to WhatsApp wins over a utm" do
    assert Source.of(
             order(%{attribution: %{"click_to_whatsapp" => true, "utm_source" => "tiktok"}})
           ) == :whatsapp
  end

  test "utm_source buckets like visits do" do
    assert Source.of(order(%{attribution: %{"utm_source" => "Instagram"}})) == :instagram
    assert Source.of(order(%{attribution: %{"utm_source" => "google"}})) == :search
    assert Source.of(order(%{attribution: %{"utm_source" => "newsletter"}})) == :other
  end

  test "no attribution is direct" do
    assert Source.of(order(%{})) == :direct
    assert Source.of(order(%{attribution: nil})) == :direct
  end

  test "tally groups orders and money, biggest money first" do
    rows =
      Source.tally([
        order(%{attribution: %{"utm_source" => "instagram"}, total: 500}),
        order(%{attribution: %{"utm_source" => "instagram"}, total: 700}),
        order(%{pay_link_id: "p", total: 2_000}),
        order(%{})
      ])

    assert [
             %{source: :pay_link, label: "Pay link", orders: 1, money: 2_000},
             %{source: :instagram, label: "Instagram", orders: 2, money: 1_200},
             %{source: :direct, label: "Typed the link or saved it", orders: 1, money: 100}
           ] = rows
  end

  test "every visit bucket StoreVisit can store has a label" do
    one_of =
      Ash.Resource.Info.attribute(Emakola.Analytics.StoreVisit, :source).constraints[:one_of]

    assert one_of -- Map.keys(Source.labels()) == []
  end
end
