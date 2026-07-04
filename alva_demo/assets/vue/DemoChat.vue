<script setup lang="ts">
import { useAlvaApi, ashForm } from 'alva'
import { Events } from '../js/alva/events'

const props = defineProps<{
  messages: any[]
}>()

const api = useAlvaApi<Events>()

const form = ashForm(api, 'messages.create', {
  initialValues: { content: '', username: 'Guest' },
  onSuccess: () => {
    form.values.content = ''
  }
})
</script>

<template>
  <div class="border rounded shadow-md p-6 bg-white">
    <div class="h-80 overflow-y-auto mb-4 border-b flex flex-col gap-3 p-4">
      <div v-for="msg in messages" :key="msg.id" class="p-3 bg-blue-50 rounded-lg max-w-[80%]">
        <strong class="text-blue-800 text-sm">{{ msg.username }}</strong>
        <p class="text-gray-800">{{ msg.content }}</p>
      </div>
      <div v-if="messages.length === 0" class="text-gray-400 italic text-center mt-10">No messages yet.</div>
    </div>
    
    <form @submit.prevent="form.submit" class="flex gap-2">
      <input v-model="form.values.username" placeholder="Name" class="border p-2 rounded w-1/4 outline-none focus:ring-2 focus:ring-blue-500" required />
      <input v-model="form.values.content" placeholder="Type a message..." class="border p-2 rounded flex-1 outline-none focus:ring-2 focus:ring-blue-500" required />
      <button type="submit" class="bg-blue-600 hover:bg-blue-700 text-white font-medium px-6 py-2 rounded transition-colors shadow-sm" :disabled="form.loading.value">
        Send
      </button>
    </form>
    <div v-if="form.errors.value.content" class="text-red-500 text-sm mt-1">
      {{ form.errors.value.content.join(', ') }}
    </div>
  </div>
</template>
