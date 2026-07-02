import { describe, it, expect, vi } from 'vitest'
import { useAlvaQuery } from './useAlvaQuery'
import { nextTick } from 'vue'

// Mock vue's onMounted so we can trigger it manually for testing
vi.mock('vue', async () => {
  const actual = await vi.importActual('vue')
  return {
    ...actual,
    onMounted: vi.fn((fn) => fn())
  }
})

describe('useAlvaQuery', () => {
  const mockApi = () => {
    const handlers: Record<string, Function> = {}
    return {
      call: vi.fn(),
      on: vi.fn((event, cb) => {
        handlers[event] = cb
      }),
      // Helper for tests
      trigger: (event: string, payload: any) => {
        if (handlers[event]) handlers[event](payload)
      }
    }
  }

  it('should initialize with loading state and empty data by default', async () => {
    const api = mockApi()
    api.call.mockResolvedValue({ ok: true, data: [] })
    
    const { data, loading, error } = useAlvaQuery(api as any, 'students.list')
    
    // onMounted mock runs immediately, but fetch is async
    expect(loading.value).toBe(true)
    expect(data.value).toEqual([])
    expect(error.value).toBe(null)
    
    await new Promise(resolve => setTimeout(resolve, 0))
    
    expect(loading.value).toBe(false)
    expect(api.call).toHaveBeenCalledWith('students.list', undefined)
  })

  it('should initialize with provided data and not auto fetch', () => {
    const api = mockApi()
    const { data, loading } = useAlvaQuery(api as any, 'students.list', undefined, { 
      initialData: [{ id: 1, name: 'Test' }] 
    })
    
    expect(loading.value).toBe(false)
    expect(data.value).toEqual([{ id: 1, name: 'Test' }])
    expect(api.call).not.toHaveBeenCalled()
  })

  it('should fetch data and update refs on success', async () => {
    const api = mockApi()
    api.call.mockResolvedValue({ ok: true, data: [{ id: 2, name: 'Fetched' }], meta: { page: 1 } })
    
    const { data, meta, error, loading } = useAlvaQuery(api as any, 'students.list')
    
    // Wait for async fetch
    await new Promise(resolve => setTimeout(resolve, 0))
    
    expect(loading.value).toBe(false)
    expect(data.value).toEqual([{ id: 2, name: 'Fetched' }])
    expect(meta.value).toEqual({ page: 1 })
    expect(error.value).toBeNull()
  })

  it('should handle fetch error', async () => {
    const api = mockApi()
    const mockError = { type: 'validation', message: 'Failed' }
    api.call.mockResolvedValue({ ok: false, error: mockError })
    
    const { error, loading } = useAlvaQuery(api as any, 'students.list')
    
    await new Promise(resolve => setTimeout(resolve, 0))
    
    expect(loading.value).toBe(false)
    expect(error.value).toEqual(mockError)
  })

  it('should handle stream insertions and updates', () => {
    const api = mockApi()
    const { data } = useAlvaQuery(api as any, 'students.list', undefined, {
      initialData: [{ id: 1, name: 'A' }],
      streamInsertEvent: 'student_created'
    })
    
    expect(api.on).toHaveBeenCalledWith('student_created', expect.any(Function))
    
    // Insert new
    api.trigger('student_created', { id: 2, name: 'B' })
    expect(data.value).toEqual([{ id: 1, name: 'A' }, { id: 2, name: 'B' }])
    
    // Update existing
    api.trigger('student_created', { id: 1, name: 'A updated' })
    expect(data.value).toEqual([{ id: 1, name: 'A updated' }, { id: 2, name: 'B' }])
  })

  it('should handle stream deletions', () => {
    const api = mockApi()
    const { data } = useAlvaQuery(api as any, 'students.list', undefined, {
      initialData: [{ id: 1, name: 'A' }, { id: 2, name: 'B' }],
      streamDeleteEvent: 'student_deleted'
    })
    
    expect(api.on).toHaveBeenCalledWith('student_deleted', expect.any(Function))
    
    // Delete by object with id
    api.trigger('student_deleted', { id: 1 })
    expect(data.value).toEqual([{ id: 2, name: 'B' }])
    
    // Delete by raw id (if server sends just the id)
    api.trigger('student_deleted', 2)
    expect(data.value).toEqual([])
  })
})
