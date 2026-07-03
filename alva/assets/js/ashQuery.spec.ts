import { describe, it, expect, vi } from 'vitest'
import { ashQuery } from './ashQuery'

// Mock vue's onMounted so we can trigger it manually for testing
vi.mock('vue', async () => {
  const actual = await vi.importActual('vue')
  return {
    ...actual,
    onMounted: vi.fn((fn) => fn())
  }
})

describe('ashQuery', () => {
  const mockApi = () => {
    return {
      call: vi.fn()
    }
  }

  it('should initialize with loading state and empty data by default', async () => {
    const api = mockApi()
    api.call.mockResolvedValue({ ok: true, data: [] })
    
    const { data, loading, error } = ashQuery(api as any, 'students.list')
    
    expect(loading.value).toBe(true)
    expect(data.value).toEqual([])
    expect(error.value).toBe(null)
    
    await new Promise(resolve => setTimeout(resolve, 0))
    
    expect(loading.value).toBe(false)
    expect(api.call).toHaveBeenCalledWith('students.list', undefined)
  })

  it('should initialize with provided data and not auto fetch', () => {
    const api = mockApi()
    const { data, loading } = ashQuery(api as any, 'students.list', undefined, { 
      initialData: [{ id: 1, name: 'Test' }] 
    })
    
    expect(loading.value).toBe(false)
    expect(data.value).toEqual([{ id: 1, name: 'Test' }])
    expect(api.call).not.toHaveBeenCalled()
  })

  it('should fetch data and update refs on success', async () => {
    const api = mockApi()
    api.call.mockResolvedValue({ ok: true, data: [{ id: 2, name: 'Fetched' }], meta: { page: 1 } })
    
    const { data, meta, error, loading } = ashQuery(api as any, 'students.list')
    
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
    
    const { error, loading } = ashQuery(api as any, 'students.list')
    
    await new Promise(resolve => setTimeout(resolve, 0))
    
    expect(loading.value).toBe(false)
    expect(error.value).toEqual(mockError)
  })
})
