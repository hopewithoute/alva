defmodule AlvaDemo.Academics do
  use Ash.Domain

  resources do
    resource AlvaDemo.Academics.Student
  end
end
