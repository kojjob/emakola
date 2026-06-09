defmodule Emakola.Fulfillment.Pipelines.StubPipelinesTest do
  @moduledoc """
  Regression baseline for the six Phase-2+ fulfillment pipeline stubs.

  Each pipeline currently returns `{:error, :not_implemented}`. These tests
  will fail the moment a developer changes that contract without also
  adding real tests — preventing silent regressions.
  """

  use ExUnit.Case, async: true

  alias Emakola.Fulfillment.Pipelines.Auction
  alias Emakola.Fulfillment.Pipelines.Course
  alias Emakola.Fulfillment.Pipelines.LicenseKey
  alias Emakola.Fulfillment.Pipelines.Physical
  alias Emakola.Fulfillment.Pipelines.PrintOnDemand
  alias Emakola.Fulfillment.Pipelines.Streaming

  describe "Physical" do
    test "returns {:error, :not_implemented} (stub — Phase 2)" do
      assert {:error, :not_implemented} = Physical.fulfill(%{}, %{})
    end
  end

  describe "LicenseKey" do
    test "returns {:error, :not_implemented} (stub — Phase 2)" do
      assert {:error, :not_implemented} = LicenseKey.fulfill(%{}, %{})
    end
  end

  describe "Course" do
    test "returns {:error, :not_implemented} (stub — Phase 5)" do
      assert {:error, :not_implemented} = Course.fulfill(%{}, %{})
    end
  end

  describe "Streaming" do
    test "returns {:error, :not_implemented} (stub — Phase 3)" do
      assert {:error, :not_implemented} = Streaming.fulfill(%{}, %{})
    end
  end

  describe "Auction" do
    test "returns {:error, :not_implemented} (stub — Phase 3/4)" do
      assert {:error, :not_implemented} = Auction.fulfill(%{}, %{})
    end
  end

  describe "PrintOnDemand" do
    test "returns {:error, :not_implemented} (stub — Phase 4)" do
      assert {:error, :not_implemented} = PrintOnDemand.fulfill(%{}, %{})
    end
  end
end
