defmodule AlvaDemoWeb.SupportDispatcherTest do
  use AlvaDemoWeb.ConnCase
  import Alva.Test
  alias Phoenix.LiveView.Socket

  describe "support.create and support.list_conversations events" do
    test "creates conversation by customer name and lists them" do
      socket = %Socket{
        private: %{alva: %{domains: [AlvaDemo.Support]}},
        assigns: %{}
      }

      result1 = assert_dispatch_ok(socket, "support.create", %{"customer_name" => "Alice"})
      assert result1.ok == true
      assert result1.data.customer_name == "Alice"
      conversation_id = result1.data.id

      # Upsert behavior check
      result2 = assert_dispatch_ok(socket, "support.create", %{"customer_name" => "Alice"})
      assert result2.data.id == conversation_id

      # List conversations
      result3 = assert_dispatch_ok(socket, "support.list_conversations", %{})
      assert result3.ok == true
      assert length(result3.data) > 0
      assert Enum.any?(result3.data, fn c -> c.id == conversation_id end)
    end
  end

  describe "support.send_message and support.list_messages events" do
    test "sends messages and lists them by conversation_id" do
      conversation = Ash.Seed.seed!(%AlvaDemo.Support.Conversation{
        customer_name: "Bob"
      })

      socket = %Socket{
        private: %{alva: %{domains: [AlvaDemo.Support]}},
        assigns: %{}
      }

      # Shopper message
      msg1 = assert_dispatch_ok(socket, "support.send_message", %{
        "text" => "Help me",
        "sender" => "shopper",
        "conversation_id" => conversation.id
      })
      assert msg1.ok == true

      # Merchant response
      msg2 = assert_dispatch_ok(socket, "support.send_message", %{
        "text" => "How can I help?",
        "sender" => "merchant",
        "conversation_id" => conversation.id
      })
      assert msg2.ok == true

      # List messages
      result = assert_dispatch_ok(socket, "support.list_messages", %{
        "conversation_id" => conversation.id
      })
      
      assert result.ok == true
      assert length(result.data) == 2
      texts = Enum.map(result.data, & &1.text)
      assert "Help me" in texts
      assert "How can I help?" in texts
    end
  end
end
