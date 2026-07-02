<template>
  <div class="max-w-2xl mx-auto mt-10 p-6 bg-white shadow rounded-lg">
    <h1 class="text-3xl font-bold mb-6 text-gray-800">Students</h1>
    
    <div v-if="loading" class="text-gray-500 animate-pulse">Loading students...</div>
    <div v-else-if="error" class="text-red-500 bg-red-50 p-4 rounded">{{ error }}</div>
    
    <div v-else class="overflow-hidden border border-gray-200 rounded-md">
      <ul class="divide-y divide-gray-200">
        <li v-for="student in students" :key="student.id" class="p-4 flex justify-between items-center hover:bg-gray-50">
          <span class="font-medium text-gray-900">{{ student.name }}</span>
          <span class="px-2 py-1 text-xs font-semibold rounded-full" 
                :class="student.status === 'active' ? 'bg-green-100 text-green-800' : 'bg-gray-100 text-gray-800'">
            {{ student.status }}
          </span>
        </li>
      </ul>
      <div v-if="students.length === 0" class="p-8 text-center text-gray-500">
        No students found.
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted } from 'vue'

interface Student {
  id: string
  name: string
  status: 'active' | 'archived'
}

const props = defineProps<{
  $live: {
    pushEvent: (event: string, payload: any, callback: (reply: any) => void) => void
  }
}>()

const students = ref<Student[]>([])
const loading = ref(true)
const error = ref<string | null>(null)

onMounted(() => {
  props.$live.pushEvent('students.list', {}, (reply: any) => {
    loading.value = false
    if (reply.ok) {
      students.value = reply.data
    } else {
      error.value = reply.error?.message || 'Unknown error'
    }
  })
})
</script>
