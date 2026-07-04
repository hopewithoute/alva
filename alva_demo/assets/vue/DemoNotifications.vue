<script setup lang="ts">
import { useAlvaApi, ashForm } from 'alva'
import { ref } from 'vue'
import { Events } from '../js/alva/events'

const api = useAlvaApi<Events>()

const toasts = ref<any[]>([])

api.bind_signal('notifications.created', (payload) => {
  const id = Date.now()
  toasts.value.push({ id, ...payload })
  
  setTimeout(() => {
    toasts.value = toasts.value.filter(t => t.id !== id)
  }, 5000)
})

const form = ashForm(api, 'notifications.create', {
  initialValues: { message: 'Hello from the client!', type: 'success' }
})
</script>

<template>
  <div class="border rounded shadow-md p-6 bg-white relative overflow-hidden min-h-[400px]">
    <div class="mb-6">
      <h2 class="text-xl font-semibold mb-2">Trigger a Notification</h2>
      <p class="text-sm text-gray-500 mb-4">Open this page in another tab. When you trigger a notification, the signal will broadcast it to all connected clients!</p>
      
      <form @submit.prevent="form.submit" class="flex flex-col gap-3 max-w-sm">
        <select v-model="form.values.type" class="border p-2 rounded outline-none focus:ring-2 focus:ring-indigo-500 bg-white">
          <option value="info">Info</option>
          <option value="success">Success</option>
          <option value="warning">Warning</option>
          <option value="error">Error</option>
        </select>
        <input v-model="form.values.message" class="border p-2 rounded outline-none focus:ring-2 focus:ring-indigo-500" required />
        <button type="submit" class="bg-indigo-600 hover:bg-indigo-700 text-white font-medium px-4 py-2 rounded transition-colors shadow-sm" :disabled="form.loading.value">
          {{ form.loading.value ? 'Triggering...' : 'Trigger Signal' }}
        </button>
      </form>
    </div>
    
    <div class="absolute top-4 right-4 flex flex-col gap-2 z-50">
      <div 
        v-for="toast in toasts" 
        :key="toast.id" 
        class="px-4 py-3 rounded shadow-lg text-white font-medium min-w-[200px] transition-all transform flex items-center justify-between"
        :class="{
          'bg-blue-500': toast.type === 'info',
          'bg-green-500': toast.type === 'success',
          'bg-yellow-500': toast.type === 'warning',
          'bg-red-500': toast.type === 'error'
        }"
      >
        <span>{{ toast.message }}</span>
        <button @click="toasts = toasts.filter(t => t.id !== toast.id)" class="ml-4 opacity-70 hover:opacity-100 font-bold">&times;</button>
      </div>
    </div>
  </div>
</template>
