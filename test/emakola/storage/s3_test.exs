defmodule Emakola.Storage.S3Test do
  use ExUnit.Case, async: true

  alias Emakola.Storage.S3

  describe "behaviour implementation" do
    test "module implements Emakola.Storage behaviour" do
      behaviours =
        S3.__info__(:attributes)
        |> Keyword.get_values(:behaviour)
        |> List.flatten()

      assert Emakola.Storage in behaviours
    end

    test "exports upload function" do
      # upload/3 has default opts, so it compiles as upload/2 and upload/3
      assert function_exported?(S3, :upload, 2) or function_exported?(S3, :upload, 3)
    end

    test "exports delete/1" do
      assert function_exported?(S3, :delete, 1)
    end

    test "exports presigned_url function" do
      assert function_exported?(S3, :presigned_url, 1) or
               function_exported?(S3, :presigned_url, 2)
    end
  end

  describe "presigned_url/2" do
    setup do
      # Set fake AWS credentials so ExAws.Config doesn't try to fetch from instance metadata
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
