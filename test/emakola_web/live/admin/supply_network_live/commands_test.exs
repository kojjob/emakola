defmodule EmakolaWeb.Admin.SupplyNetworkLive.CommandsTest do
  use ExUnit.Case, async: true

  alias EmakolaWeb.Admin.SupplyNetworkLive.Commands

  test "confirmation requires a previewed command" do
    assert Commands.execute(nil, "store-1", [], nil) ==
             {:error, "Preview an instruction before confirming it."}
  end

  test "content and Sales Kit commands explain their prerequisite without mutating" do
    assert Commands.execute(nil, "store-1", [], %{action: :create_content}) ==
             {:error, "Add a partner product before creating content."}

    assert Commands.execute(nil, "store-1", [], %{action: :create_sales_kit}) ==
             {:error, "Add a partner product before creating a Sales Kit."}
  end
end
