defmodule AlvaDemoWeb.AlvaTest do
  use AlvaDemo.DataCase

  test "dispatch/3 handles students.list event" do
    AlvaDemo.Academics.Student
    |> Ash.Changeset.for_create(:create, %{name: "Budi"})
    |> Ash.create!()

    {:reply, reply, _socket} = AlvaDemoWeb.Alva.dispatch("students.list", %{}, %{})

    assert reply.ok == true
    assert length(reply.data) == 1
    assert hd(reply.data).name == "Budi"
  end

  test "dispatch/3 handles unknown events" do
    {:reply, reply, _socket} = AlvaDemoWeb.Alva.dispatch("unknown", %{}, %{})
    assert reply.ok == false
    assert reply.error.type == "unknown"
  end
end
