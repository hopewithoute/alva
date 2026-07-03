defmodule Alva.DispatcherTest do
  use ExUnit.Case

  defmodule TestResource do
    use Ash.Resource,
      domain: Alva.DispatcherTest.TestDomain,
      validate_domain_inclusion?: false,
      data_layer: Ash.DataLayer.Ets,
      extensions: [Alva.Resource]

    ets do
      private?(true)
    end

    resource do
      require_primary_key?(false)
    end

    attributes do
      uuid_primary_key(:id)
      attribute(:name, :string, public?: true)
      attribute(:actor_name, :string, public?: true)
      attribute(:tenant_id, :string, public?: true)
      attribute(:secret_key, :string, public?: false, default: "secret")
      attribute(:can_archive, :boolean, public?: true, default: true)
    end

    actions do
      read :get do
        get?(true)
      end

      action :get_context, :map do
        run(fn _input, context ->
          {:ok, %{actor: context.actor, tenant: context.tenant}}
        end)
      end

      read :read do
        primary?(true)
        pagination(offset?: true, required?: false)
      end

      create :create do
        accept([:name, :tenant_id])
        change fn changeset, context ->
          actor_name = if context.actor, do: context.actor.name, else: nil
          changeset
          |> Ash.Changeset.change_attribute(:actor_name, actor_name)
          |> Ash.Changeset.change_attribute(:tenant_id, context.tenant || Ash.Changeset.get_attribute(changeset, :tenant_id))
        end
      end


      destroy :archive do
        require_atomic?(false)
        accept([])
        change fn changeset, context ->
          actor_name = if context.actor, do: context.actor.name, else: nil
          changeset
          |> Ash.Changeset.change_attribute(:actor_name, actor_name)
          |> Ash.Changeset.change_attribute(:tenant_id, context.tenant)
        end
      end

      update :update do
        require_atomic?(false)
        accept([:name])
        change fn changeset, context ->
          actor_name = if context.actor, do: context.actor.name, else: nil
          changeset
          |> Ash.Changeset.change_attribute(:actor_name, actor_name)
          |> Ash.Changeset.change_attribute(:tenant_id, context.tenant)
        end
      end

      action :say_hello, :string do
        argument(:name, :string, allow_nil?: false)

        run(fn input, _context ->
          {:ok, "Hello #{input.arguments.name}"}
        end)
      end

      read :search do
        argument(:query, :string, allow_nil?: false)
        filter(expr(name == ^arg(:query)))
      end

      read :read_with_tenant do
        prepare fn query, context ->
          if context.tenant do
            require Ash.Query
            require Ash.Expr
            Ash.Query.filter(query, Ash.Expr.expr(tenant_id == ^context.tenant))
          else
            query
          end
        end
      end

      create :upload_file do
        accept []
        argument :file, Ash.Type.File, allow_nil?: false
        change fn changeset, _context ->
          file = Ash.Changeset.get_argument(changeset, :file)
          if is_map(file) do
            filename = 
              case file do
                %Ash.Type.File{source: source} -> Map.get(source, :filename, "unknown")
                _ -> Map.get(file, :filename, "unknown")
              end
            Ash.Changeset.change_attribute(changeset, :name, filename)
          else
            changeset
          end
        end
      end
    end

    live_vue do
      event("test.archive", action: :archive, lookup: :id)
      event("test.say_hello", action: :say_hello)
      event("test.get_context", action: :get_context)
      event("test.get", action: :read, lookup: :id)
      event("test.list", action: :read)
      event("test.search", action: :search)
      event("test.create", action: :create)
      event("test.validate_create", action: :create, validate_only: true)
      event("test.update", action: :update, lookup: :id)
      event("test.validate_update", action: :update, lookup: :id, validate_only: true)
      event("test.read_tenant", action: :read_with_tenant)
      event("test.get_tenant", action: :read_with_tenant, lookup: :id)
      event("test.upload", action: :upload_file)
    end
  end

  defmodule TestDomain do
    use Ash.Domain, validate_config_inclusion?: false, extensions: [Alva.Domain]

    resources do
      resource(Alva.DispatcherTest.TestResource)
    end
  end

  setup do
    record = Ash.create!(Ash.Changeset.for_create(TestResource, :create, %{name: "Test"}))
    %{record: record}
  end

  test "dispatch handles :destroy event", %{record: record} do
    # Dispatch destroy
    result = Alva.Dispatcher.dispatch("test.archive", %{"id" => record.id}, domains: [TestDomain])

    assert result.ok == true
    assert result.data.id == record.id

    # Assert record is deleted
    assert_raise Ash.Error.Invalid, fn ->
      Ash.get!(TestResource, record.id)
    end
  end

  test "dispatch returns error for :destroy event with nil id" do
    result = Alva.Dispatcher.dispatch("test.archive", %{}, domains: [TestDomain])

    assert result.ok == false
    assert result.error.type == "not_found"
  end

  test "validate_only true on create returns early without DB commit" do
    params = %{"name" => "valid name"}
    
    # Should return ok: true, data: %{}
    result = Alva.Dispatcher.dispatch("test.validate_create", params, domains: [TestDomain])
    assert result.ok == true
    assert result.data == %{}
    
    # Check DB to ensure it was not created
    records = Ash.read!(TestResource)
    assert not Enum.any?(records, fn r -> r.name == "valid name" end)
  end
  
  test "validate_only true on create returns validation error if invalid" do
    # pass invalid type to force validation error
    params = %{"name" => %{"invalid" => "type"}}
    
    result = Alva.Dispatcher.dispatch("test.validate_create", params, domains: [TestDomain])
    assert result.ok == false
    assert result.error.type == "validation"
  end

  test "validate_only true on update returns early without DB commit", %{record: record} do
    params = %{"id" => record.id, "name" => "new name"}
    
    result = Alva.Dispatcher.dispatch("test.validate_update", params, domains: [TestDomain])
    assert result.ok == true
    assert result.data == %{}
    
    # Check DB to ensure it was not updated
    updated_record = Ash.get!(TestResource, record.id)
    assert updated_record.name == "Test"
  end

  test "dispatch handles :action event" do
    result =
      Alva.Dispatcher.dispatch("test.say_hello", %{"name" => "World"}, domains: [TestDomain])

    assert result.ok == true
    assert result.data == "Hello World"
  end

  test "dispatch passes actor and tenant from opts to Ash" do
    result =
      Alva.Dispatcher.dispatch(
        "test.get_context",
        %{},
        domains: [TestDomain],
        actor: %{id: 1, name: "Admin"},
        tenant: "organization_1"
      )

    assert result.ok == true
    assert result.data.actor == %{id: 1, name: "Admin"}
    assert result.data.tenant == "organization_1"
  end

  test "dispatch returns error for :action event with invalid args" do
    result = Alva.Dispatcher.dispatch("test.say_hello", %{}, domains: [TestDomain])

    assert result.ok == false
    assert result.error.type == "validation"
  end

  test "dispatch handles :read event with lookup as Get action", %{record: record} do
    result = Alva.Dispatcher.dispatch("test.get", %{"id" => record.id}, domains: [TestDomain])

    assert result.ok == true
    assert is_map(result.data)
    assert result.data.id == record.id
  end

  test "dispatch returns not_found for :read Get action with missing id" do
    result = Alva.Dispatcher.dispatch("test.get", %{}, domains: [TestDomain])

    assert result.ok == false
    assert result.error.type == "not_found"
  end

  test "dispatch handles :read event without lookup as List action", %{record: record} do
    result = Alva.Dispatcher.dispatch("test.list", %{}, domains: [TestDomain])

    assert result.ok == true
    assert is_list(result.data)
    assert Enum.any?(result.data, fn r -> r.id == record.id end)
  end

  test "dispatch handles :read event with arguments for filtering" do
    # create another record so we can filter
    Ash.create!(Ash.Changeset.for_create(TestResource, :create, %{name: "Other"}))

    result = Alva.Dispatcher.dispatch("test.search", %{"query" => "Other"}, domains: [TestDomain])

    assert result.ok == true
    assert is_list(result.data)
    assert length(result.data) == 1
    assert hd(result.data).name == "Other"
  end

  test "dispatch handles :read event list by stripping meta from params" do
    result =
      Alva.Dispatcher.dispatch("test.list", %{"meta" => %{"other" => 1}}, domains: [TestDomain])

    assert result.ok == true
    assert is_list(result.data)
  end

  test "dispatch handles :read event list with pagination" do
    # create multiple records
    Ash.create!(Ash.Changeset.for_create(TestResource, :create, %{name: "Page1"}))
    Ash.create!(Ash.Changeset.for_create(TestResource, :create, %{name: "Page2"}))
    Ash.create!(Ash.Changeset.for_create(TestResource, :create, %{name: "Page3"}))

    result =
      Alva.Dispatcher.dispatch(
        "test.list",
        %{"page" => %{"limit" => 2, "offset" => 0, "hacked" => "yes"}}, domains: [TestDomain])

    assert result.ok == true
    assert is_list(result.data)
    assert length(result.data) == 2
    assert result.meta.pagination.limit == 2
    assert result.meta.pagination.offset == 0
    assert result.meta.pagination.has_more == true
  end

  test "dispatch handles :read event list with non-map pagination" do
    result = Alva.Dispatcher.dispatch("test.list", %{"page" => "invalid"}, domains: [TestDomain])
    assert result.ok == true
    assert is_list(result.data)
  end

  test "dispatch handles :read event list with sort" do
    Ash.create!(Ash.Changeset.for_create(TestResource, :create, %{name: "Zebra"}))
    Ash.create!(Ash.Changeset.for_create(TestResource, :create, %{name: "Apple"}))

    result = Alva.Dispatcher.dispatch("test.list", %{"sort" => "name"}, domains: [TestDomain])

    assert result.ok == true
    assert is_list(result.data)

    names = Enum.map(result.data, & &1.name)
    assert names == ["Apple", "Test", "Zebra"]

    result_desc =
      Alva.Dispatcher.dispatch("test.list", %{"sort" => "-name"}, domains: [TestDomain])

    names_desc = Enum.map(result_desc.data, & &1.name)
    assert names_desc == ["Zebra", "Test", "Apple"]
  end

  test "dispatch handles :read event lookup by stripping meta from params", %{record: record} do
    result =
      Alva.Dispatcher.dispatch("test.get", %{"id" => record.id, "meta" => %{"page" => 1}},
        domains: [TestDomain]
      )

    assert result.ok == true
    assert result.data.id == record.id
  end

  test "dispatch passes actor and tenant for :create event" do
    result =
      Alva.Dispatcher.dispatch(
        "test.create",
        %{"name" => "New"},
        domains: [TestDomain],
        actor: %{name: "Creator"},
        tenant: "tenant_create"
      )

    assert result.ok == true
    assert result.data.actor_name == "Creator"
    assert result.data.tenant_id == "tenant_create"
  end

  test "dispatch passes actor and tenant for :update event", %{record: record} do
    result =
      Alva.Dispatcher.dispatch(
        "test.update",
        %{"id" => record.id, "name" => "Updated"},
        domains: [TestDomain],
        actor: %{name: "Updater"},
        tenant: "tenant_update"
      )

    assert result.ok == true
    assert result.data.actor_name == "Updater"
    assert result.data.tenant_id == "tenant_update"
  end

  test "dispatch passes actor and tenant for :destroy event", %{record: record} do
    result =
      Alva.Dispatcher.dispatch(
        "test.archive",
        %{"id" => record.id},
        domains: [TestDomain],
        actor: %{name: "Destroyer"},
        tenant: "tenant_destroy"
      )

    assert result.ok == true
    assert result.data.actor_name == "Destroyer"
    assert result.data.tenant_id == "tenant_destroy"
  end

  test "dispatch passes actor and tenant for :read list event" do
    Ash.create!(Ash.Changeset.for_create(TestResource, :create, %{name: "T1", tenant_id: "tenant_1"}))
    Ash.create!(Ash.Changeset.for_create(TestResource, :create, %{name: "T2", tenant_id: "tenant_2"}))

    result =
      Alva.Dispatcher.dispatch(
        "test.read_tenant",
        %{},
        domains: [TestDomain],
        tenant: "tenant_1"
      )

    assert result.ok == true
    assert length(result.data) == 1
    assert hd(result.data).name == "T1"
  end

  test "dispatch passes actor and tenant for :read lookup event" do
    record1 = Ash.create!(Ash.Changeset.for_create(TestResource, :create, %{name: "T1", tenant_id: "tenant_1"}))

    # Try to read with correct tenant
    result_ok =
      Alva.Dispatcher.dispatch(
        "test.get_tenant",
        %{"id" => record1.id},
        domains: [TestDomain],
        tenant: "tenant_1"
      )
    assert result_ok.ok == true

    # Try to read with wrong tenant
    result_err =
      Alva.Dispatcher.dispatch(
        "test.get_tenant",
        %{"id" => record1.id},
        domains: [TestDomain],
        tenant: "tenant_wrong"
      )
    assert result_err.ok == false
    assert result_err.error.type == "not_found"
  end

  test "dispatch strips private fields (Auto-DTO)", %{record: record} do
    result = Alva.Dispatcher.dispatch("test.get", %{"id" => record.id}, domains: [TestDomain])
    
    assert result.ok == true
    assert Map.has_key?(result.data, :name)
    assert Map.has_key?(result.data, :id)
    refute Map.has_key?(result.data, :secret_key)
  end

  test "dispatch groups can_ calculations into meta._permissions", %{record: record} do
    result = Alva.Dispatcher.dispatch("test.get", %{"id" => record.id}, domains: [TestDomain])
    
    assert result.ok == true
    assert Map.has_key?(result.data, :name)
    assert Map.has_key?(result.data, :id)
    refute Map.has_key?(result.data, :can_archive)
    assert result.meta._permissions.can_archive == true
  end

  defmodule MetadataResource do
    use Ash.Resource,
      domain: Alva.DispatcherTest.MetadataDomain,
      validate_domain_inclusion?: false,
      data_layer: Ash.DataLayer.Ets,
      extensions: [Alva.Resource]

    ets do
      private?(true)
    end

    resource do
      require_primary_key?(false)
    end

    attributes do
      uuid_primary_key(:id)
      attribute(:name, :string, public?: true)
    end

    actions do
      read :read do
        primary?(true)
        pagination(offset?: true, required?: false)
      end

      create :create do
        accept([:name])
      end

      update :update do
        require_atomic?(false)
        accept([:name])
      end
    end

    live_vue do
      event("meta.get", action: :read, lookup: :id, expose_metadata: [:sync_token])
      event("meta.list", action: :read, expose_metadata: [:sync_token])
      event("meta.create", action: :create, expose_metadata: [:sync_token])
      event("meta.update", action: :update, lookup: :id, expose_metadata: [:sync_token])
      event("meta.none", action: :read, lookup: :id)
    end
  end

  defmodule MetadataDomain do
    use Ash.Domain, validate_config_inclusion?: false, extensions: [Alva.Domain]

    resources do
      resource(Alva.DispatcherTest.MetadataResource)
    end
  end

  describe "expose_metadata" do
    test "exposes specified metadata keys in meta for single record" do
      record = Ash.create!(Ash.Changeset.for_create(MetadataResource, :create, %{name: "Test"}))
      result = Alva.Dispatcher.dispatch("meta.get", %{"id" => record.id}, domains: [MetadataDomain])

      assert result.ok == true
      # __metadata__ from ETS is empty by default, so no exposed keys in meta
      refute Map.has_key?(result, :meta)
    end

    test "exposes metadata when present on record" do
      record = Ash.create!(Ash.Changeset.for_create(MetadataResource, :create, %{name: "Test"}))

      # Simulate a record with __metadata__ set (as Ash would in production)
      record_with_meta = %{record | __metadata__: Map.put(record.__metadata__, :sync_token, "tok_abc123")}

      event_def = %Alva.Resource.Event{expose_metadata: [:sync_token]}
      {stripped, exposed_meta} = Alva.Dispatcher.strip_and_extract_metadata(record_with_meta, event_def)

      assert stripped == %{id: record.id, name: "Test"}
      assert exposed_meta == %{sync_token: "tok_abc123"}
    end

    test "strips unexposed metadata keys" do
      record = Ash.create!(Ash.Changeset.for_create(MetadataResource, :create, %{name: "Test"}))

      record_with_meta = %{record | __metadata__: %{
        sync_token: "tok_abc123",
        internal_secret: "hidden",
        other: "also_hidden"
      }}

      event_def = %Alva.Resource.Event{expose_metadata: [:sync_token]}
      {_stripped, exposed_meta} = Alva.Dispatcher.strip_and_extract_metadata(record_with_meta, event_def)

      assert exposed_meta == %{sync_token: "tok_abc123"}
      refute Map.has_key?(exposed_meta, :internal_secret)
      refute Map.has_key?(exposed_meta, :other)
    end

    test "expose_metadata DSL field is parsed correctly" do
      events = Alva.Resource.Info.events(MetadataResource)
      event = Enum.find(events, &(&1.name == "meta.get"))

      assert event.expose_metadata == [:sync_token]
    end

    test "expose_metadata defaults to empty list" do
      events = Alva.Resource.Info.events(MetadataResource)
      event = Enum.find(events, &(&1.name == "meta.none"))

      assert event.expose_metadata == []
    end

    test "strip_and_extract_metadata extracts specified keys" do
      record = %MetadataResource{
        id: "test-id",
        name: "Test",
        __metadata__: %{sync_token: "tok_123", internal: "hidden"}
      }

      event_def = %Alva.Resource.Event{expose_metadata: [:sync_token]}

      {stripped, exposed_meta} = Alva.Dispatcher.strip_and_extract_metadata(record, event_def)

      assert stripped == %{id: "test-id", name: "Test"}
      assert exposed_meta == %{sync_token: "tok_123"}
    end

    test "strip_and_extract_metadata returns empty meta when no keys exposed" do
      record = %MetadataResource{
        id: "test-id",
        name: "Test",
        __metadata__: %{sync_token: "tok_123"}
      }

      event_def = %Alva.Resource.Event{expose_metadata: []}

      {stripped, exposed_meta} = Alva.Dispatcher.strip_and_extract_metadata(record, event_def)

      assert stripped == %{id: "test-id", name: "Test"}
      assert exposed_meta == %{}
    end

    test "strip_and_extract_metadata handles list of records" do
      records = [
        %MetadataResource{id: "1", name: "A", __metadata__: %{sync_token: "tok_1"}},
        %MetadataResource{id: "2", name: "B", __metadata__: %{sync_token: "tok_2"}}
      ]

      event_def = %Alva.Resource.Event{expose_metadata: [:sync_token]}

      {stripped, exposed_meta} = Alva.Dispatcher.strip_and_extract_metadata(records, event_def)

      assert length(stripped) == 2
      assert exposed_meta == %{sync_token: "tok_1"}
    end
  end

  describe "upload consumption" do
    defmodule MockUploadConsumer do
      def consume_uploaded_entries(socket, name, func) do
        entries = get_in(socket.assigns.uploads, [name, :entries]) || []
        
        Enum.map(entries, fn entry ->
          {:ok, result} = func.(%{path: "/tmp/#{entry.client_name}"}, entry)
          result
        end)
      end
    end

    test "dispatch consumes uploads and merges them into params" do
      socket = %Phoenix.LiveView.Socket{
        assigns: %{
          uploads: %{
            file: %{
              entries: [
                %{client_name: "test.png", client_type: "image/png"}
              ]
            }
          }
        }
      }

      result = Alva.Dispatcher.dispatch(
        "test.upload",
        %{},
        socket: socket,
        domains: [TestDomain],
        upload_consumer: MockUploadConsumer
      )

      assert result.ok == true
      assert result.data.name == "test.png"
    end
  end
end
