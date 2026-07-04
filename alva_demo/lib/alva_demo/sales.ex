defmodule AlvaDemo.Sales do
  use Ash.Domain,
    extensions: [Alva.Domain]

  resources do
    resource(AlvaDemo.Sales.Order)
  end
end
