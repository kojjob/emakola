defmodule Emakola.Infra.FlyCertsBehaviour do
  @moduledoc """
  Provisioning and inspection of TLS certificates for merchant custom domains.

  Behind a behaviour so the verification worker can be tested without reaching
  Fly, and so a future move to a different certificate provider touches one
  module.
  """

  @type status :: Emakola.Infra.FlyCerts.Status.t()

  @callback add_certificate(String.t()) :: {:ok, status()} | {:error, term()}
  @callback get_certificate(String.t()) :: {:ok, status() | nil} | {:error, term()}
  @callback delete_certificate(String.t()) :: :ok | {:error, term()}
end
