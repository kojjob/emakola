defmodule Emakola.Onboarding.SetupChecklistTest do
  @moduledoc """
  Pins the contract for SetupChecklist:

    * Returns a stable list of 5 steps regardless of done state
    * Each step has all required fields (key, done?, title, etc.)
    * theme_set? recognises both "theme" and "theme_id" keys
    * Detection short-circuits on nil / empty
    * `complete?/2` returns true only when ALL steps are done
    * `completed_count/2` matches done step count
  """
  use ExUnit.Case, async: true

  alias Emakola.Onboarding.SetupChecklist
  alias Emakola.Stores.Store

  defp empty_store do
    %Store{
      theme_config: %{},
      whatsapp_number: nil,
      instagram_url: nil,
      tiktok_url: nil,
      facebook_url: nil,
      youtube_url: nil,
      x_url: nil
    }
  end

  describe "steps/2" do
    test "returns 5 steps in stable order" do
      steps = SetupChecklist.steps(empty_store())

      assert length(steps) == 5

      assert Enum.map(steps, & &1.key) == [
               :theme,
               :first_product,
               :delivery_zones,
               :whatsapp,
               :social
             ]
    end

    test "each step has all required fields" do
      for step <- SetupChecklist.steps(empty_store()) do
        assert is_atom(step.key)
        assert is_boolean(step.done?)
        assert is_binary(step.title)
        assert is_binary(step.description)
        assert is_binary(step.cta_label)
        assert is_binary(step.cta_path)
        assert is_binary(step.icon)
      end
    end

    test "all steps undone for an empty store with zero counts" do
      for step <- SetupChecklist.steps(empty_store()) do
        refute step.done?, "expected #{step.key} to be undone for empty store"
      end
    end

    test "all steps done for a fully-configured store" do
      store = %Store{
        empty_store()
        | theme_config: %{"theme" => "atelier"},
          whatsapp_number: "+233244123456",
          instagram_url: "https://instagram.com/foo"
      }

      steps = SetupChecklist.steps(store, product_count: 5, delivery_zone_count: 3)

      for step <- steps do
        assert step.done?, "expected #{step.key} to be done for fully-configured store"
      end
    end
  end

  describe "theme detection" do
    test "recognises theme_config['theme']" do
      store = %Store{empty_store() | theme_config: %{"theme" => "starter"}}
      [theme_step | _] = SetupChecklist.steps(store)
      assert theme_step.done?
    end

    test "also recognises theme_config['theme_id'] (alternate key)" do
      store = %Store{empty_store() | theme_config: %{"theme_id" => "atelier"}}
      [theme_step | _] = SetupChecklist.steps(store)
      assert theme_step.done?
    end

    test "treats empty-string theme as undone" do
      store = %Store{empty_store() | theme_config: %{"theme" => ""}}
      [theme_step | _] = SetupChecklist.steps(store)
      refute theme_step.done?
    end

    test "treats missing theme_config keys as undone" do
      store = %Store{empty_store() | theme_config: %{"unrelated" => "value"}}
      [theme_step | _] = SetupChecklist.steps(store)
      refute theme_step.done?
    end
  end

  describe "product/delivery counts" do
    test "products step done when product_count > 0" do
      [_, products_step | _] = SetupChecklist.steps(empty_store(), product_count: 1)
      assert products_step.done?
    end

    test "products step undone when product_count is 0 (default)" do
      [_, products_step | _] = SetupChecklist.steps(empty_store())
      refute products_step.done?
    end

    test "delivery step done when delivery_zone_count > 0" do
      [_, _, delivery_step | _] = SetupChecklist.steps(empty_store(), delivery_zone_count: 1)
      assert delivery_step.done?
    end
  end

  describe "whatsapp detection" do
    test "done when whatsapp_number is set" do
      store = %Store{empty_store() | whatsapp_number: "+233244123456"}
      whatsapp_step = Enum.find(SetupChecklist.steps(store), &(&1.key == :whatsapp))
      assert whatsapp_step.done?
    end

    test "undone when whatsapp_number is nil or empty" do
      for phone <- [nil, ""] do
        store = %Store{empty_store() | whatsapp_number: phone}
        whatsapp_step = Enum.find(SetupChecklist.steps(store), &(&1.key == :whatsapp))
        refute whatsapp_step.done?, "expected undone for whatsapp_number=#{inspect(phone)}"
      end
    end
  end

  describe "social detection" do
    test "done when ANY of the 5 social URLs is set" do
      for field <- [:instagram_url, :tiktok_url, :facebook_url, :youtube_url, :x_url] do
        store = struct(empty_store(), [{field, "https://example.com/foo"}])
        social_step = Enum.find(SetupChecklist.steps(store), &(&1.key == :social))
        assert social_step.done?, "expected done when only #{field} is set"
      end
    end

    test "undone when all social URLs are nil or empty" do
      social_step = Enum.find(SetupChecklist.steps(empty_store()), &(&1.key == :social))
      refute social_step.done?
    end
  end

  describe "completed_count/2 and complete?/2" do
    test "completed_count returns 0 for empty store" do
      assert SetupChecklist.completed_count(empty_store()) == 0
    end

    test "completed_count matches done step count" do
      store = %Store{
        empty_store()
        | theme_config: %{"theme" => "starter"},
          whatsapp_number: "+233244123456"
      }

      assert SetupChecklist.completed_count(store) == 2
    end

    test "complete? false until all steps done" do
      store = %Store{empty_store() | theme_config: %{"theme" => "starter"}}
      refute SetupChecklist.complete?(store)
    end

    test "complete? true when all 5 steps done" do
      store = %Store{
        empty_store()
        | theme_config: %{"theme" => "starter"},
          whatsapp_number: "+233244123456",
          instagram_url: "https://instagram.com/foo"
      }

      assert SetupChecklist.complete?(store, product_count: 1, delivery_zone_count: 1)
    end
  end
end
