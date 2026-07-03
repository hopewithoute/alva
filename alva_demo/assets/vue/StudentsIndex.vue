<template>
  <div class="max-w-2xl mx-auto mt-10 p-6 bg-white shadow rounded-lg">
    <h1 class="text-3xl font-bold mb-6 text-gray-800">Students</h1>
    
    <div v-if="latestSignal" class="mb-4 p-4 bg-blue-100 text-blue-800 rounded-md">
      Signal Received: {{ latestSignal }}
    </div>

    <form @submit.prevent="createStudent" class="mb-6">
      <div class="flex gap-4">
        <input 
          v-model="newName" 
          type="text" 
          placeholder="New student name" 
          class="flex-1 rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 px-3"
          :class="{'border-red-500 focus:border-red-500 focus:ring-red-500': fieldErrors.name}"
          :disabled="isCreating"
        />
        <button 
          type="submit" 
          class="bg-indigo-600 text-white px-4 py-2 rounded-md hover:bg-indigo-700 disabled:opacity-50"
          :disabled="isCreating"
        >
          {{ isCreating ? 'Adding...' : 'Add Student' }}
        </button>
      </div>
      <p v-if="fieldErrors.name" class="mt-1 text-sm text-red-600">{{ fieldErrors.name[0] }}</p>
    </form>
    
    <div v-if="loading" class="text-gray-500 animate-pulse">Loading students...</div>
    <div v-else-if="error" class="text-red-500 bg-red-50 p-4 rounded">{{ error }}</div>
    
    <div v-else class="overflow-hidden border border-gray-200 rounded-md">
      <ul class="divide-y divide-gray-200">
        <li v-for="student in students" :key="student.id" class="p-4 flex justify-between items-center hover:bg-gray-50" :class="{'opacity-50 line-through': student.status === 'archived'}">
          <span class="font-medium text-gray-900">{{ student.name }}</span>
          <div class="flex items-center gap-3">
            <span class="px-2 py-1 text-xs font-semibold rounded-full" 
                  :class="student.status === 'active' ? 'bg-green-100 text-green-800' : 'bg-gray-100 text-gray-800'">
              {{ student.status }}
            </span>
            <button 
              v-if="student.status === 'active'"
              @click="archiveStudent(student.id)" 
              class="text-sm text-red-600 hover:text-red-800"
            >
              Archive
            </button>
          </div>
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
import { useAlvaApi } from 'alva'

interface Student {
  id: string
  name: string
  status: 'active' | 'archived'
}

type AlvaEvents = {
  'students.list': { input: {}; output: { ok: true, data: Student[] } | { ok: false, error: any } }
  'students.create': { input: { name: string | null }; output: { ok: true, data: Student } | { ok: false, error: any } }
  'students.archive': { input: { id: string }; output: { ok: true, data: Student } | { ok: false, error: any } }
}

type SignalEvents = {
  'students.created': { data: Student }
}

const props = defineProps<{
  students: Student[]
}>()

const api = useAlvaApi<AlvaEvents, SignalEvents>()

const loading = ref(false)
const error = ref<string | null>(null)
const fieldErrors = ref<Record<string, string[]>>({})

const newName = ref('')
const isCreating = ref(false)
const latestSignal = ref<string | null>(null)

api.on('students.created', (payload) => {
  latestSignal.value = `Student '${payload.data.name}' was just added (Signal)`
  setTimeout(() => { latestSignal.value = null }, 3000)
})

const createStudent = async () => {
  isCreating.value = true
  error.value = null
  fieldErrors.value = {}
  
  const reply = await api.ashCall('students.create', { name: newName.value.trim() ? newName.value : null })
  
  isCreating.value = false
  if (reply.ok) {
    // Route Collection is updated via LiveVue stream path.
    newName.value = ''
  } else {
    if (reply.error?.type === 'validation') {
      fieldErrors.value = reply.error.fields || {}
    } else {
      error.value = reply.error?.message || 'Failed to create student'
    }
  }
}

const archiveStudent = async (id: string) => {
  const reply = await api.ashCall('students.archive', { id })
  if (!reply.ok) {
    alert(reply.error?.message || 'Failed to archive student')
  }
}
</script>
