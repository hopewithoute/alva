import { useLiveVue } from 'live_vue'

export type LiveErrorType = 
  | "validation" 
  | "forbidden" 
  | "not_found" 
  | "conflict" 
  | "stale" 
  | "unknown"

export type LiveError = {
  type: LiveErrorType
  message: string
  code?: string
  fields?: Record<string, string[]>
  meta?: unknown
}

export type LiveResult<T = any> =
  | { ok: true; data: T; meta?: Record<string, unknown> }
  | { ok: false; error: LiveError }

export interface AlvaApiConfig {
  onError?: (error: LiveError, event: string) => void
  onSuccess?: (data: any, event: string) => void
}

export function useAlvaApi<Events extends Record<string, { input: any; output: LiveResult<any> }> = any>(config?: AlvaApiConfig) {
  const live = useLiveVue()

  const call = <E extends keyof Events>(
    event: E,
    payload: Events[E]['input']
  ): Promise<Events[E]['output']> => {
    return new Promise((resolve) => {
      live.pushEvent(event as string, payload, (reply: any) => {
        if (reply.ok) {
          config?.onSuccess?.(reply.data, event as string)
          resolve(reply as Events[E]['output'])
        } else {
          config?.onError?.(reply.error, event as string)
          resolve(reply as Events[E]['output'])
        }
      })
    })
  }

  return {
    call
  }
}
