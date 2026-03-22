defmodule Emakola.Storage.S3Test do
  use ExUnit.Case, async: true

  alias Emakola.Storage.S3

  describe "module structure" do
    test "S3 module is defined and loadable" do
      assert Code.ensure_loaded?(S3)
    end

    test "S3 module declares Storage behaviour" do
      behaviours =
        S3.__info__(:attributes)
        |> Keyword.get_values(:behaviour)
        |> List.flatten()

      assert Emakola.Storage in behaviours
    end
  end

  describe "presigned_url/2" do
    setup do
      Application.put_env(:ex_aws, :access_key_id, "test-key-id")
      Application.put_env(:ex_aws, :secret_access_key, "test-secret-key")

      on_exit(fn ->
        Application.delete_env(:ex_aws, :access_key_id)
        Application.delete_env(:ex_aws, :secret_access_key)
      end)

      :ok
    end

    test "generates a presigned URL containing the path" do
      assert {:ok, url} = S3.presigned_url("images/test.jpg", expires_in: 3600)
      assert is_binary(url)
      assert String.contains?(url, "images/test.jpg")
    end

    test "generates url with default expiry" do
      assert {:ok, url} = S3.presigned_url("uploads/photo.png")
      assert is_binary(url)
      assert String.contains?(url, "uploads/photo.png")
    end
  end
end
