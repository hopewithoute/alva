import { describe, it, expect, vi } from 'vitest'
import { useAlvaApi } from './useAlvaApi'
import { useLiveVue, useLiveEvent } from 'live_vue'

vi.mock('live_vue', () => {
  return {
    useLiveVue: vi.fn(),
    useLiveEvent: vi.fn()
  }
})

describe('useAlvaApi', () => {
  it('should call live.pushEvent and resolve with success payload', async () => {
    const pushEventMock = vi.fn((event, payload, callback) => {
      callback({ ok: true, data: { id: 1 } })
    })
    
    vi.mocked(useLiveVue).mockReturnValue({
      pushEvent: pushEventMock
    } as any)

    const api = useAlvaApi()
    const result = await api.call('students.create', { name: 'Test' })
    
    expect(pushEventMock).toHaveBeenCalledWith('students.create', { name: 'Test' }, expect.any(Function))
    expect(result).toEqual({ ok: true, data: { id: 1 } })
  })

  it('should trigger onSuccess if provided', async () => {
    const pushEventMock = vi.fn((event, payload, callback) => {
      callback({ ok: true, data: { id: 2 } })
    })
    
    vi.mocked(useLiveVue).mockReturnValue({
      pushEvent: pushEventMock
    } as any)

    const onSuccess = vi.fn()
    const api = useAlvaApi({ onSuccess })
    
    await api.call('students.create', { name: 'Test 2' })
    
    expect(onSuccess).toHaveBeenCalledWith({ id: 2 }, 'students.create')
  })

  it('should trigger onError if provided when ok is false', async () => {
    const errorResponse = { type: 'validation', message: 'Invalid data' }
    const pushEventMock = vi.fn((event, payload, callback) => {
      callback({ ok: false, error: errorResponse })
    })
    
    vi.mocked(useLiveVue).mockReturnValue({
      pushEvent: pushEventMock
    } as any)

    const onError = vi.fn()
    const api = useAlvaApi({ onError })
    
    const result = await api.call('students.create', { name: '' })
    
    expect(onError).toHaveBeenCalledWith(errorResponse, 'students.create')
    expect(result).toEqual({ ok: false, error: errorResponse })
  })

  it('should register a pubsub event using on() which calls useLiveEvent', () => {
    const api = useAlvaApi()
    const callback = vi.fn()
    
    api.on('post_created', callback)
    
    expect(useLiveEvent).toHaveBeenCalledWith('post_created', callback)
  })
})
