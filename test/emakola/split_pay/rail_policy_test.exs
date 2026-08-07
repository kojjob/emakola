defmodule Emakola.SplitPay.RailPolicyTest do
  @moduledoc """
  Rail resolution: an explicit `rail:` option wins, then the per-store
  gateway pin list, then the configured default, then `:internal_first`.
  Anything outside the two known rails raises rather than silently routing.
  """
  use ExUnit.Case, async: false

  alias Emakola.SplitPay.RailPolicy

  setup do
    original = Application.get_env(:emakola, Emakola.SplitPay)

    on_exit(fn ->
      if original,
        do: Application.put_env(:emakola, Emakola.SplitPay, original),
        else: Application.delete_env(:emakola, Emakola.SplitPay)
    end)

    :ok
  end

  test "an explicit :rail option wins over config and pins" do
    Application.put_env(:emakola, Emakola.SplitPay,
      default_rail: :internal_first,
      gateway_rail_store_ids: ["pinned"]
    )

    assert RailPolicy.rail("pinned", rail: :internal_first) == :internal_first
    assert RailPolicy.rail("unpinned", rail: :gateway_first) == :gateway_first
  end

  test "a pinned store routes gateway_first regardless of the default" do
    Application.put_env(:emakola, Emakola.SplitPay,
      default_rail: :internal_first,
      gateway_rail_store_ids: ["pinned"]
    )

    assert RailPolicy.rail("pinned") == :gateway_first
    assert RailPolicy.rail("unpinned") == :internal_first
  end

  test "config default_rail decides when no pin applies" do
    Application.put_env(:emakola, Emakola.SplitPay, default_rail: :gateway_first)

    assert RailPolicy.rail("any") == :gateway_first
  end

  test "absent config falls back to :internal_first" do
    Application.delete_env(:emakola, Emakola.SplitPay)

    assert RailPolicy.rail("any") == :internal_first
  end

  test "an unknown rail raises instead of routing" do
    assert_raise ArgumentError, fn -> RailPolicy.rail("any", rail: :sideways) end

    Application.put_env(:emakola, Emakola.SplitPay, default_rail: :bogus)
    assert_raise ArgumentError, fn -> RailPolicy.rail("any") end
  end
end
