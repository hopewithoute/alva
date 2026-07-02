import { ref, onMounted, Ref } from 'vue'
import type { LiveError } from './useAlvaApi'

export interface AshQueryOptions<T, PubSubEvents> {
  initialData?: T[]
  autoFetch?: boolean
  streamInsertEvent?: keyof PubSubEvents
  streamDeleteEvent?: keyof PubSubEvents
  primaryKey?: string
}

export function ashQuery<
  Events extends Record<string, { input: any; output: any }>,
  PubSubEvents extends Record<string, any>,
  E extends keyof Events,
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
  const primaryKey = options.primaryKey || 'id'

  const fetch = async () => {
    loading.value = true
    error.value = null
    const result = await api.call(event, params)
    
    if (result.ok) {
      if (!Array.isArray(result.data)) {
        console.warn(`[ashQuery] Expected array response for ${String(event)}, but got ${typeof result.data}.`)
      }
      data.value = result.data as unknown as T[]
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

  const updateArray = (item: any, isDelete = false) => {
    const pkValue = typeof item === 'object' && item !== null ? item[primaryKey] : item
    if (pkValue === undefined || pkValue === null) return

    const index = data.value.findIndex((existing: any) => existing[primaryKey] === pkValue)
    
    if (index >= 0) {
      const newData = [...data.value]
      if (isDelete) {
        newData.splice(index, 1)
      } else {
        newData.splice(index, 1, item as T)
      }
      data.value = newData as any
    } else if (!isDelete) {
      data.value = [...data.value, item as T] as any
    }
  }

  if (options.streamInsertEvent) {
    api.on(options.streamInsertEvent, (payload: any) => {
      updateArray(payload, false)
    })
  }

  if (options.streamDeleteEvent) {
    api.on(options.streamDeleteEvent, (payload: any) => {
      updateArray(payload, true)
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
