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
      conversation =
        Ash.Seed.seed!(%AlvaDemo.Support.Conversation{
          customer_name: "Bob"
        })

      socket = %Socket{
        private: %{alva: %{domains: [AlvaDemo.Support]}},
        assigns: %{}
      }

      # Shopper message
      msg1 =
        assert_dispatch_ok(socket, "support.send_message", %{
          "text" => "Help me",
          "sender" => "shopper",
          "conversation_id" => conversation.id
        })

      assert msg1.ok == true

      # Merchant response
      msg2 =
        assert_dispatch_ok(socket, "support.send_message", %{
          "text" => "How can I help?",
          "sender" => "merchant",
          "conversation_id" => conversation.id
        })

      assert msg2.ok == true

      # List messages
      result =
        assert_dispatch_ok(socket, "support.list_messages", %{
          "conversation_id" => conversation.id
        })

      assert result.ok == true
      assert length(result.data) == 2
      texts = Enum.map(result.data, & &1.text)
      assert "Help me" in texts
      assert "How can I help?" in texts
    end

    test "updates conversation summaries and waiting filters for the merchant queue" do
      conversation =
        Ash.Seed.seed!(%AlvaDemo.Support.Conversation{
          customer_name: "Queue Bob"
        })

      socket = %Socket{
        private: %{alva: %{domains: [AlvaDemo.Support]}},
        assigns: %{}
      }

      assert_dispatch_ok(socket, "support.send_message", %{
        "text" => "Need help with my order",
        "sender" => "shopper",
        "conversation_id" => conversation.id
      })

      waiting_result =
        assert_dispatch_ok(socket, "support.list_conversations", %{
          "needs_merchant_reply" => true
        })

      queued_conversation =
        Enum.find(waiting_result.data, fn result -> result.id == conversation.id end)

      assert queued_conversation
      assert queued_conversation.needs_merchant_reply == true
      assert queued_conversation.message_count == 1
      assert queued_conversation.last_message_sender == "shopper"
      assert queued_conversation.last_message_preview == "Need help with my order"

      assert_dispatch_ok(socket, "support.send_message", %{
        "text" => "We are on it",
        "sender" => "merchant",
        "conversation_id" => conversation.id
      })

      customer_result =
        assert_dispatch_ok(socket, "support.list_conversations", %{
          "customer_query" => "Queue"
        })

      updated_conversation =
        Enum.find(customer_result.data, fn result -> result.id == conversation.id end)

      assert updated_conversation
      assert updated_conversation.needs_merchant_reply == false
      assert updated_conversation.message_count == 2
      assert updated_conversation.last_message_sender == "merchant"
      assert updated_conversation.last_message_preview == "We are on it"

      waiting_again =
        assert_dispatch_ok(socket, "support.list_conversations", %{
          "needs_merchant_reply" => true
        })

      refute Enum.any?(waiting_again.data, fn result -> result.id == conversation.id end)
    end
  end
end
