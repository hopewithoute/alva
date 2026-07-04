<script setup lang="ts">
import { useAlvaApi, ashForm } from 'alva'
import { ref } from 'vue'
import { Events } from '../js/alva/events'

const props = defineProps<{
  students: any[]
}>()

const api = useAlvaApi<Events>()

const loadingMore = ref(false)
const hasMore = ref(true)

const loadMore = async () => {
  if (loadingMore.value || !hasMore.value) return
  
  loadingMore.value = true
  
  // By sending `students.list`, the server-side bind_stream_query intercepts the result 
  // and patches it directly into the stream.
  // We can pass limit and offset for pagination
  const result = await api.call('students.list', {
    query: {
      limit: 5,
      offset: props.students.length,
      sort: [{ field: 'inserted_at', order: 'desc' }]
    }
  })
  
  if (result.ok) {
    if (result.data.length < 5) {
      hasMore.value = false
    }
  }
  
  loadingMore.value = false
}

// Initial load
if (props.students.length === 0) {
  loadMore()
}
</script>

<template>
  <div class="border rounded shadow-md p-6 bg-white min-h-[400px]">
    <h2 class="text-xl font-semibold mb-4">Students Directory</h2>
    
    <div class="flex flex-col gap-3">
      <div v-for="student in students" :key="student.id" class="p-4 border rounded hover:bg-gray-50 flex justify-between items-center transition-colors">
        <span class="font-medium text-gray-900">{{ student.name }}</span>
        <span class="text-sm px-2 py-1 rounded-full bg-blue-100 text-blue-800">
          {{ new Date(student.inserted_at).toLocaleDateString() }}
        </span>
      </div>
      
      <div v-if="students.length === 0 && !loadingMore" class="p-8 text-center text-gray-500 italic">
        No students found.
      </div>
    </div>
    
    <div class="mt-6 text-center">
      <button 
        v-if="hasMore"
        @click="loadMore" 
        :disabled="loadingMore"
        class="bg-gray-100 hover:bg-gray-200 text-gray-800 font-medium px-6 py-2 rounded-full transition-colors disabled:opacity-50"
      >
        {{ loadingMore ? 'Loading...' : 'Load More' }}
      </button>
      <p v-else class="text-gray-400 text-sm italic">You've reached the end of the list.</p>
    </div>
  </div>
</template>
