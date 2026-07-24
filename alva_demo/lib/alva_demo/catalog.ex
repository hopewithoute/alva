defmodule AlvaDemo.Catalog do
  use Ash.Domain

  resources do
    resource(AlvaDemo.Catalog.Product)
  end
end
