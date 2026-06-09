defmodule Emakola.Fulfillment.DispatcherTest do
  use ExUnit.Case, async: true

  alias Emakola.Fulfillment.Dispatcher

  alias Emakola.Fulfillment.Pipelines.{
    Auction,
    Course,
    DigitalDownload,
    LicenseKey,
    Physical,
    PrintOnDemand,
    Streaming
  }

  describe "dispatch/3" do
    test "routes :physical to the Physical pipeline" do
      assert {:error, :not_implemented} = Dispatcher.dispatch(:physical, %{}, %{})
    end

    test "routes :digital_download to the DigitalDownload pipeline" do
      # DigitalDownload is wired (Phase 1); calling it with a fake/empty
      # line item now hits real code and returns :line_item_not_found
      # rather than the old :not_implemented stub. Either error proves
      # the routing worked — what we're asserting here is *routing*, not
      # the pipeline's own behavior (that's covered in
      # Pipelines.DigitalDownloadTest).
      assert {:error, :line_item_not_found} =
               Dispatcher.dispatch(:digital_download, %{id: Ecto.UUID.generate()}, %{})
    end

    test "routes :license_key to the LicenseKey pipeline" do
      assert {:error, :not_implemented} = Dispatcher.dispatch(:license_key, %{}, %{})
    end

    test "routes :streaming to the Streaming pipeline" do
      assert {:error, :not_implemented} = Dispatcher.dispatch(:streaming, %{}, %{})
    end

    test "routes :course to the Course pipeline" do
      assert {:error, :not_implemented} = Dispatcher.dispatch(:course, %{}, %{})
    end

    test "routes :auction to the Auction pipeline" do
      assert {:error, :not_implemented} = Dispatcher.dispatch(:auction, %{}, %{})
    end

    test "routes :print_on_demand to the PrintOnDemand pipeline" do
      assert {:error, :not_implemented} = Dispatcher.dispatch(:print_on_demand, %{}, %{})
    end

    test "returns {:error, {:unknown_product_type, atom}} for an unknown type" do
      assert {:error, {:unknown_product_type, :not_a_real_type}} =
               Dispatcher.dispatch(:not_a_real_type, %{}, %{})
    end

    test "context argument is optional and defaults to an empty map" do
      assert {:error, :not_implemented} = Dispatcher.dispatch(:physical, %{})
    end
  end

  describe "pipeline_for/1" do
    test "returns the pipeline module for each valid product_type" do
      assert Dispatcher.pipeline_for(:physical) == Physical
      assert Dispatcher.pipeline_for(:digital_download) == DigitalDownload
      assert Dispatcher.pipeline_for(:license_key) == LicenseKey
      assert Dispatcher.pipeline_for(:streaming) == Streaming
      assert Dispatcher.pipeline_for(:course) == Course
      assert Dispatcher.pipeline_for(:auction) == Auction
      assert Dispatcher.pipeline_for(:print_on_demand) == PrintOnDemand
    end

    test "returns nil for an unknown product_type" do
      assert Dispatcher.pipeline_for(:not_a_real_type) == nil
    end
  end

  describe "supported_types/0" do
    test "lists every product_type the dispatcher knows about" do
      assert MapSet.new(Dispatcher.supported_types()) ==
               MapSet.new([
                 :physical,
                 :digital_download,
                 :license_key,
                 :streaming,
                 :course,
                 :auction,
                 :print_on_demand
               ])
    end

    test "stays in lockstep with Catalog.Product :product_type one_of constraint" do
      [product_type_attr] =
        Emakola.Catalog.Product
        |> Ash.Resource.Info.attributes()
        |> Enum.filter(&(&1.name == :product_type))

      one_of = product_type_attr.constraints[:one_of]

      assert MapSet.new(Dispatcher.supported_types()) == MapSet.new(one_of),
             """
             Dispatcher.supported_types/0 and Product :product_type one_of constraint drifted.
             Add or remove the type in both places.

             Dispatcher:  #{inspect(Enum.sort(Dispatcher.supported_types()))}
             Product:     #{inspect(Enum.sort(one_of))}
             """
    end
  end

  describe "pipeline behaviour conformance" do
    test "every pipeline module implements Emakola.Fulfillment.Pipeline" do
      for {_type, pipeline} <- [
            physical: Physical,
            digital_download: DigitalDownload,
            license_key: LicenseKey,
            streaming: Streaming,
            course: Course,
            auction: Auction,
            print_on_demand: PrintOnDemand
          ] do
        Code.ensure_loaded!(pipeline)

        assert function_exported?(pipeline, :fulfill, 2),
               "#{inspect(pipeline)} is missing fulfill/2"

        behaviours =
          pipeline.module_info(:attributes)
          |> Keyword.get_values(:behaviour)
          |> List.flatten()

        assert Emakola.Fulfillment.Pipeline in behaviours,
               "#{inspect(pipeline)} does not declare @behaviour Emakola.Fulfillment.Pipeline"
      end
    end
  end
end
