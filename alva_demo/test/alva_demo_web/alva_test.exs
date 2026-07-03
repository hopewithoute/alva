defmodule AlvaDemoWeb.AlvaTest do
  use AlvaDemo.DataCase

  require Alva.Test

  test "dispatch/3 handles students.list event using Alva.Test helper" do
    AlvaDemo.Academics.Student
    |> Ash.Changeset.for_create(:create, %{name: "Budi"})
    |> Ash.create!()

    socket = %Phoenix.LiveView.Socket{assigns: %{foo: "bar"}}
    
    # We can use Alva.Test helpers to verify the boundary (Alva.Dispatcher) directly
    reply = Alva.Test.assert_dispatch_ok(socket, "students.list", %{}, domains: [AlvaDemo.Academics])

    assert length(reply.data) == 1
    assert hd(reply.data).name == "Budi"
    
    # Verify the demo's custom wrapper still works for the reply strategy
    {:reply, wrapper_reply, returned_socket} = AlvaDemoWeb.Alva.dispatch("students.list", %{}, socket)
    assert wrapper_reply.ok == true
    assert returned_socket == socket
    assert returned_socket.assigns.foo == "bar"
  end

  test "dispatch/3 handles students.create event (happy path) using Alva.Test helper" do
    params = %{"name" => "Siti"}
    socket = %Phoenix.LiveView.Socket{}
    
    reply = Alva.Test.assert_dispatch_ok(socket, "students.create", params, domains: [AlvaDemo.Academics])

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
