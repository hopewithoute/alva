defmodule AlvaDemo.Catalog do
  use Ash.Domain,
    extensions: [Alva.Domain]

  resources do
    resource AlvaDemo.Catalog.Product
  end
end
