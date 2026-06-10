defmodule Emakola.Fulfillment.Pipelines.StubPipelinesTest do
  @moduledoc """
  Regression baseline for the six Phase-2+ fulfillment pipeline stubs.

  Each stub returns `{:ok, :deferred}` to signal that fulfillment is pending
  a future phase without producing log noise at INFO level. These tests will
  fail the moment a developer changes that contract without also adding real
  tests — preventing silent regressions.
  """

  use ExUnit.Case, async: true

  alias Emakola.Fulfillment.Pipelines.Auction
  alias Emakola.Fulfillment.Pipelines.Course
  alias Emakola.Fulfillment.Pipelines.LicenseKey
  alias Emakola.Fulfillment.Pipelines.Physical
  alias Emakola.Fulfillment.Pipelines.PrintOnDemand
  alias Emakola.Fulfillment.Pipelines.Streaming

  describe "Physical" do
    test "returns {:ok, :deferred} (stub — Phase 2)" do
      assert {:ok, :deferred} = Physical.fulfill(%{}, %{})
    end
  end

  describe "LicenseKey" do
    test "returns {:ok, :deferred} (stub — Phase 2)" do
      assert {:ok, :deferred} = LicenseKey.fulfill(%{}, %{})
    end
  end

  describe "Course" do
    test "returns {:ok, :deferred} (stub — Phase 5)" do
      assert {:ok, :deferred} = Course.fulfill(%{}, %{})
    end
  end

  describe "Streaming" do
    test "returns {:ok, :deferred} (stub — Phase 3)" do
      assert {:ok, :deferred} = Streaming.fulfill(%{}, %{})
    end
  end

  describe "Auction" do
    test "returns {:ok, :deferred} (stub — Phase 3/4)" do
      assert {:ok, :deferred} = Auction.fulfill(%{}, %{})
    end
  end

  describe "PrintOnDemand" do
    test "returns {:ok, :deferred} (stub — Phase 4)" do
      assert {:ok, :deferred} = PrintOnDemand.fulfill(%{}, %{})
    end
  end
end
