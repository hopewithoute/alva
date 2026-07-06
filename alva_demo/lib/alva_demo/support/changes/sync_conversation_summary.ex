defmodule AlvaDemo.Support.Changes.SyncConversationSummary do
  use Ash.Resource.Change

  alias AlvaDemo.Support.Conversation

  def change(changeset, _opts, _context) do
    Ash.Changeset.after_action(changeset, fn _changeset, message ->
      with {:ok, conversation} <- Ash.get(Conversation, message.conversation_id),
           attrs <- conversation_summary_attrs(conversation, message),
           {:ok, _updated_conversation} <-
             conversation
             |> Ash.Changeset.for_update(:record_message, attrs)
             |> Ash.update() do
        {:ok, message}
      end
    end)
  end

  defp conversation_summary_attrs(conversation, message) do
    %{
      last_message_at: message.created_at,
      last_message_preview: String.slice(message.text, 0, 140),
      last_message_sender: message.sender,
      needs_merchant_reply: message.sender == :shopper,
      message_count: (conversation.message_count || 0) + 1
    }
  end
end
