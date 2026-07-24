defmodule AlvaDemo.Sales do
  use Ash.Domain

  resources do
    resource(AlvaDemo.Sales.Order)
  end
end
