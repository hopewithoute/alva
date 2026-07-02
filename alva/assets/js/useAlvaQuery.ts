import { ref, onMounted, Ref } from 'vue'
import type { LiveError } from './useAlvaApi'

export interface AshQueryOptions<T, PubSubEvents> {
  initialData?: T[]
  autoFetch?: boolean
  streamInsertEvent?: keyof PubSubEvents
  streamDeleteEvent?: keyof PubSubEvents
}

export function useAlvaQuery<
  Events extends Record<string, { input: any; output: any }>,
  PubSubEvents extends Record<string, any>,
  E extends keyof Events,
  // Extract the single item type from the array response
  T = Events[E]['output'] extends { data: infer D } ? (D extends any[] ? D[number] : D) : any
>(
  api: { 
    call: (event: E, params?: Events[E]['input']) => Promise<any>,
    on: <K extends keyof PubSubEvents>(event: K, cb: (payload: PubSubEvents[K]) => void) => void
  },
  event: E,
  params?: Events[E]['input'],
  options: AshQueryOptions<T, PubSubEvents> = {}
) {
  const data = ref(options.initialData || []) as Ref<T[]>
  const loading = ref(!options.initialData && options.autoFetch !== false)
  const error = ref<LiveError | null>(null)
  const meta = ref<Record<string, unknown> | null>(null)

  const fetch = async () => {
    loading.value = true
    error.value = null
    const result = await api.call(event, params)
    
    if (result.ok) {
      data.value = (Array.isArray(result.data) ? result.data : [result.data]) as unknown as T[]
      meta.value = result.meta || null
    } else {
      error.value = result.error
    }
    loading.value = false
  }

  if (!options.initialData && options.autoFetch !== false) {
    onMounted(() => {
      fetch()
    })
  }

  if (options.streamInsertEvent) {
    api.on(options.streamInsertEvent, (payload: any) => {
      const item = payload as T
      const id = (item as any).id
      if (id === undefined) return

      const index = data.value.findIndex((existing: any) => existing.id === id)
      
      if (index >= 0) {
        // Create a new array to ensure reactivity triggers properly
        const newData = [...data.value]
        newData.splice(index, 1, item)
        data.value = newData as any
      } else {
        data.value = [...data.value, item] as any
      }
    })
  }

  if (options.streamDeleteEvent) {
    api.on(options.streamDeleteEvent, (payload: any) => {
      const id = payload.id ?? payload
      if (id === undefined) return

      const index = data.value.findIndex((existing: any) => existing.id === id)
      if (index >= 0) {
        const newData = [...data.value]
        newData.splice(index, 1)
        data.value = newData as any
      }
    })
  }

  return {
    data,
    loading,
    error,
    meta,
    fetch
  }
}
