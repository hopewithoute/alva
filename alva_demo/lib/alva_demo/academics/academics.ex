defmodule AlvaDemo.Academics do
  use Ash.Domain, extensions: [Alva.Domain]

  resources do
    resource AlvaDemo.Academics.Student
  end
end
