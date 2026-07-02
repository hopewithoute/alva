<template>
  <div class="max-w-2xl mx-auto mt-10 p-6 bg-white shadow rounded-lg">
    <h1 class="text-3xl font-bold mb-6 text-gray-800">Students</h1>
    
    <form @submit.prevent="createStudent" class="mb-6 flex gap-4">
      <input 
        v-model="newName" 
        type="text" 
        placeholder="New student name" 
        class="flex-1 rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500"
        :disabled="isCreating"
      />
      <button 
        type="submit" 
        class="bg-indigo-600 text-white px-4 py-2 rounded-md hover:bg-indigo-700 disabled:opacity-50"
        :disabled="isCreating || !newName.trim()"
      >
        {{ isCreating ? 'Adding...' : 'Add Student' }}
      </button>
    </form>
    
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
import { useLiveVue } from 'live_vue'

interface Student {
  id: string
  name: string
  status: 'active' | 'archived'
}

const live = useLiveVue()

const students = ref<Student[]>([])
const loading = ref(true)
const error = ref<string | null>(null)

const newName = ref('')
const isCreating = ref(false)

const createStudent = () => {
  if (!newName.value.trim()) return
  
  isCreating.value = true
  live.pushEvent('students.create', { name: newName.value }, (reply: any) => {
    isCreating.value = false
    if (reply.ok) {
      students.value.push(reply.data)
      newName.value = ''
    } else {
      error.value = reply.error?.message || 'Failed to create student'
    }
  })
}

onMounted(() => {
  live.pushEvent('students.list', {}, (reply: any) => {
    loading.value = false
    if (reply.ok) {
      students.value = reply.data
    } else {
      error.value = reply.error?.message || 'Unknown error'
    }
  })
})
</script>
