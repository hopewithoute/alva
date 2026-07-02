import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest'
import { ashForm } from './ashForm'
import { nextTick } from 'vue'

describe('ashForm', () => {
  const mockApi = () => {
    return {
      call: vi.fn()
    }
  }

  beforeEach(() => {
    vi.useFakeTimers()
  })

  afterEach(() => {
    vi.useRealTimers()
  })

  it('should initialize with provided values', () => {
    const api = mockApi()
    const { values, errors, loading } = ashForm(api as any, 'students.create', {
      initialValues: { name: 'Test' }
    })
    
    expect(values.name).toBe('Test')
    expect(errors.value).toEqual({})
    expect(loading.value).toBe(false)
  })

  it('should handle successful submission', async () => {
    const api = mockApi()
    api.call.mockResolvedValue({ ok: true, data: { id: 1 } })
    
    const { values, submit, loading } = ashForm(api as any, 'students.create', {
      initialValues: { name: 'Test' }
    })
    
    const promise = submit()
    expect(loading.value).toBe(true)
    
    const result = await promise
    expect(loading.value).toBe(false)
    expect(result).toEqual({ ok: true, data: { id: 1 } })
    expect(api.call).toHaveBeenCalledWith('students.create', { name: 'Test' })
  })

  it('should handle validation errors on submit', async () => {
    const api = mockApi()
    api.call.mockResolvedValue({ 
      ok: false, 
      error: { type: 'validation', fields: { name: ["can't be blank"] } } 
    })
    
    const { submit, errors } = ashForm(api as any, 'students.create', {
      initialValues: { name: '' }
    })
    
    await submit()
    expect(errors.value).toEqual({ name: ["can't be blank"] })
  })

  it('should not map errors if type is not validation', async () => {
    const api = mockApi()
    api.call.mockResolvedValue({ 
      ok: false, 
      error: { type: 'forbidden', message: 'Not allowed' } 
    })
    
    const { submit, errors } = ashForm(api as any, 'students.create', {
      initialValues: { name: 'Test' }
    })
    
    await submit()
    expect(errors.value).toEqual({})
  })

  it('should debounce validation on field change', async () => {
    const api = mockApi()
    api.call.mockResolvedValue({ ok: true })
    
    const { values, isValidating } = ashForm(api as any, 'students.create', {
      initialValues: { name: 'A' },
      validateEvent: 'students.validate'
    })
    
    // Change value
    values.name = 'B'
    await nextTick() // Let watcher trigger
    
    expect(isValidating.value).toBe(true)
    expect(api.call).not.toHaveBeenCalled()
    
    // Fast forward timer
    vi.advanceTimersByTime(300)
    
    // Wait for promise resolution using real timers
    vi.useRealTimers()
    await new Promise(resolve => setTimeout(resolve, 0))
    
    expect(api.call).toHaveBeenCalledWith('students.validate', { name: 'B' })
    expect(isValidating.value).toBe(false)
  })

  it('should resolve hanging validation promises with cancelled status', async () => {
    const api = mockApi()
    api.call.mockResolvedValue({ ok: true })
    
    const { validate } = ashForm(api as any, 'students.create', {
      initialValues: { name: 'A' },
      validateEvent: 'students.validate'
    })
    
    const promise1 = validate()
    const promise2 = validate()
    
    vi.advanceTimersByTime(300)
    vi.useRealTimers()
    
    const [res1, res2] = await Promise.all([promise1, promise2])
    
    expect(res1).toEqual({ ok: false, error: { type: 'cancelled', message: 'Superseded' } })
    expect(res2).toEqual({ ok: true }) // The second one actually runs
    expect(api.call).toHaveBeenCalledTimes(1) // Only one call made it through the debounce
  })

  it('should cancel pending validation when submit is called to prevent race conditions', async () => {
    const api = mockApi()
    api.call.mockResolvedValue({ ok: true })
    
    const { values, submit, errors } = ashForm(api as any, 'students.create', {
      initialValues: { name: 'A' },
      validateEvent: 'students.validate'
    })
    
    // Trigger validation
    values.name = 'B'
    await nextTick()
    
    // Call submit immediately
    const submitPromise = submit()
    
    vi.advanceTimersByTime(300)
    vi.useRealTimers()
    
    await submitPromise
    
    // Validate shouldn't have been called because submit cancelled it
    expect(api.call).toHaveBeenCalledTimes(1)
    expect(api.call).toHaveBeenCalledWith('students.create', { name: 'B' })
  })
  
  it('should reset form', () => {
    const api = mockApi()
    const { values, errors, reset } = ashForm(api as any, 'students.create', {
      initialValues: { name: 'A' }
    })
    
    values.name = 'B'
    errors.value = { name: ['bad'] }
    
    reset()
    
    expect(values.name).toBe('A')
    expect(errors.value).toEqual({})
  })

  it('should attach uploads to submit payload', async () => {
    const api = mockApi()
    api.call.mockResolvedValue({ ok: true })
    
    const mockUpload = {
      getFileReferences: () => ['ref-1', 'ref-2']
    }
    
    const { submit } = ashForm(api as any, 'students.create', {
      initialValues: { name: 'Test' },
      uploads: {
        avatar: mockUpload
      }
    })
    
    await submit()
    
    expect(api.call).toHaveBeenCalledWith('students.create', {
      name: 'Test',
      avatar: ['ref-1', 'ref-2']
    })
  })
})
