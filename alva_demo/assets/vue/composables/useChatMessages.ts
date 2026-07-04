import { computed, Ref } from "vue";
import type { SupportMessage } from "../../js/alva/types";

export function useChatMessages(
  active_conversation_id: Ref<string | null | undefined>,
  historical_messages: Ref<SupportMessage[]>,
  live_messages: Ref<SupportMessage[] | undefined>
) {
  return computed(() => {
    if (!active_conversation_id.value) return [];
    
    const mergedMap = new Map<string, SupportMessage>();
    
    historical_messages.value.forEach((m: SupportMessage) => mergedMap.set(m.id, m));
    
    if (live_messages.value) {
      live_messages.value.forEach((m: SupportMessage) => {
        if (m.conversation_id === active_conversation_id.value) {
          mergedMap.set(m.id, m);
        }
      });
    }
    
    return Array.from(mergedMap.values()).sort((a, b) => 
      new Date(a.created_at).getTime() - new Date(b.created_at).getTime()
    );
  });
}
