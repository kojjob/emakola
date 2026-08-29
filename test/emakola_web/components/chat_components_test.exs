defmodule EmakolaWeb.ChatComponentsTest do
  @moduledoc """
  The grouping is what makes the chat read as a conversation instead of a
  log: consecutive messages from one side share an avatar and a timestamp.
  """
  use ExUnit.Case, async: true

  alias EmakolaWeb.ChatComponents

  defp msg(kind, id), do: %{id: id, author_kind: kind, body: "m#{id}"}

  test "consecutive messages from one side become one group" do
    groups =
      ChatComponents.group_messages([msg(:customer, 1), msg(:customer, 2), msg(:merchant, 3)])

    assert [
             %{author_kind: :customer, messages: [%{id: 1}, %{id: 2}]},
             %{author_kind: :merchant, messages: [%{id: 3}]}
           ] = groups
  end

  test "alternating sides never merge" do
    groups =
      ChatComponents.group_messages([msg(:platform, 1), msg(:merchant, 2), msg(:platform, 3)])

    assert length(groups) == 3
  end

  test "no messages, no groups" do
    assert ChatComponents.group_messages([]) == []
  end

  test "read?/2 is two-state: read only once the other side's cursor passes it" do
    now = DateTime.utc_now()
    earlier = DateTime.add(now, -60)
    message = %{inserted_at: now}

    refute ChatComponents.read?(message, nil)
    refute ChatComponents.read?(message, earlier)
    assert ChatComponents.read?(message, DateTime.add(now, 1))
  end
end
