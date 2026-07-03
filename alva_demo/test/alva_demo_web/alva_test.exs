defmodule AlvaDemoWeb.AlvaTest do
  use AlvaDemo.DataCase

  test "dispatch/3 handles students.list event" do
    AlvaDemo.Academics.Student
    |> Ash.Changeset.for_create(:create, %{name: "Budi"})
    |> Ash.create!()

    socket = %Phoenix.LiveView.Socket{assigns: %{foo: "bar"}}
    {:reply, reply, returned_socket} = AlvaDemoWeb.Alva.dispatch("students.list", %{}, socket)

    assert reply.ok == true
    assert length(reply.data) == 1
    assert hd(reply.data).name == "Budi"
    
    # Verify socket is unchanged for default :reply strategy
    assert returned_socket == socket
    assert returned_socket.assigns.foo == "bar"
  end

  test "dispatch/3 handles students.create event (happy path)" do
    params = %{"name" => "Siti"}
    {:reply, reply, _socket} = AlvaDemoWeb.Alva.dispatch("students.create", params, %{})

    assert reply.ok == true
    assert reply.data.name == "Siti"
    assert reply.data.status == :active
    assert reply.data.id != nil
  end

  test "dispatch/3 handles students.create validation error" do
    params = %{}
    {:reply, reply, _socket} = AlvaDemoWeb.Alva.dispatch("students.create", params, %{})

    assert reply.ok == false
    assert reply.error.type == "validation"
    assert reply.error.message == "Validation failed"
    assert reply.error.fields["name"] == ["is required"]
  end

  test "dispatch/3 handles students.archive successfully" do
    student = AlvaDemo.Academics.Student.create!(%{name: "To Be Archived"})

    params = %{"id" => student.id}
    assert {:reply, reply, _socket} = AlvaDemoWeb.Alva.dispatch("students.archive", params, %{})

    assert reply.ok == true
    assert reply.data.status == :archived
    assert reply.data.id == student.id
  end

  test "dispatch/3 handles students.archive not found error" do
    params = %{"id" => Ash.UUID.generate()}
    assert {:reply, reply, _socket} = AlvaDemoWeb.Alva.dispatch("students.archive", params, %{})

    assert reply.ok == false
    assert reply.error.type == "not_found"
    assert reply.error.message == "Resource not found"
  end

  test "dispatch/3 handles unknown events" do
    {:reply, reply, _socket} = AlvaDemoWeb.Alva.dispatch("unknown", %{}, %{})
    assert reply.ok == false
    assert reply.error.type == "unknown"
  end

  test "dispatch/3 handles test.assign updating socket assigns" do
    # create some data so read action has data
    student = AlvaDemo.Academics.Student.create!(%{name: "Dummy Assign"})

    socket = %Phoenix.LiveView.Socket{}
    {:reply, reply, socket} = AlvaDemoWeb.Alva.dispatch("test.assign", %{}, socket)

    assert reply.ok == true
    assert socket.assigns.dummy_key != nil
    assert hd(socket.assigns.dummy_key).id == student.id
  end
end
