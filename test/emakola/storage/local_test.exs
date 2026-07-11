defmodule Emakola.Storage.LocalTest do
  use ExUnit.Case, async: true

  test "rejects remote and path-traversal sources" do
    assert {:error, :untrusted_source_url} =
             Emakola.Storage.Local.replicate(
               "https://attacker.example/image.jpg",
               "safe/image.jpg",
               []
             )

    assert {:error, :untrusted_source_url} =
             Emakola.Storage.Local.replicate(
               "/uploads/../secrets",
               "safe/image.jpg",
               []
             )
  end
end
