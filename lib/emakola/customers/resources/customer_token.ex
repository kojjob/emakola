defmodule Emakola.Customers.CustomerToken do
  use Ash.Resource,
    domain: Emakola.Customers,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshAuthentication.TokenResource]

  postgres do
    table("customer_tokens")
    repo(Emakola.Repo)
  end

  actions do
    defaults([:read, :destroy])
  end
end
