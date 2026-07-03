import { ref, reactive, watch } from 'vue'

export interface AshFormOptions<FormValues, EventKeys> {
  initialValues: FormValues
  validateEvent?: EventKeys
  debounceMs?: number
  uploads?: Record<string, { getFileReferences: () => string[] }>
}

export function ashForm<
  Events extends Record<string, { input: any; output: any }>,
  SubmitEventKey extends keyof Events,
  FormValues = Events[SubmitEventKey]['input']
>(
  api: { call: <K extends keyof Events>(event: K, params?: Events[K]['input']) => Promise<any> },
  submitEvent: SubmitEventKey,
  options: AshFormOptions<FormValues, keyof Events>
) {
  const values = reactive({ ...options.initialValues } as any) as FormValues
  const errors = ref<Record<string, string[]>>({})
  const loading = ref(false)
  const isValidating = ref(false)

  const applyErrors = (result: any) => {
    if (!result.ok && result.error?.type === 'validation') {
      errors.value = result.error.fields || {}
    } else if (result.ok) {
      errors.value = {}
    }
  }

  let submitCounter = 0
  let validateCounter = 0
  let timeout: ReturnType<typeof setTimeout>
  let pendingResolve: ((val: any) => void) | null = null

  const submit = async () => {
    submitCounter++
    const currentSubmit = submitCounter
    
    // Cancel any pending validations to prevent race conditions
    validateCounter++ // Ensure any in-flight validation resolves without applying state
    clearTimeout(timeout)
    isValidating.value = false
    if (pendingResolve) {
      pendingResolve({ ok: false, error: { type: 'cancelled', message: 'Submit started' } })
      pendingResolve = null
    }

    loading.value = true
    errors.value = {}
    
    const payload = { ...values } as Record<string, any>
    if (options.uploads) {
      for (const [key, upload] of Object.entries(options.uploads)) {
        payload[key] = upload.getFileReferences()
      }
    }
    
    const result = await api.call(submitEvent, payload as Events[SubmitEventKey]['input'])
    
    // Only apply if another submit hasn't superseded this one
    if (currentSubmit === submitCounter) {
      applyErrors(result)
      loading.value = false
    }
    
    return result
  }

  const validate = async () => {
    if (!options.validateEvent) return { ok: true }
    
    validateCounter++
    const currentValidation = validateCounter
    
    clearTimeout(timeout)
    
    // Resolve the previous hanging promise
    if (pendingResolve) {
      pendingResolve({ ok: false, error: { type: 'cancelled', message: 'Superseded' } })
    }
    
    isValidating.value = true
    
    return new Promise((resolve) => {
      pendingResolve = resolve
      timeout = setTimeout(async () => {
        const result = await api.call(options.validateEvent!, values as any)
        
        // Only apply if this is still the most recent validation and no submit has occurred
        if (currentValidation === validateCounter && !loading.value) {
          applyErrors(result)
          isValidating.value = false
        }
        
        if (pendingResolve === resolve) {
          pendingResolve = null
        }
        resolve(result)
      }, options.debounceMs || 300)
    })
  }

  if (options.validateEvent) {
    watch(values as any, () => {
      validate()
    }, { deep: true })
  }

  const reset = () => {
    Object.assign(values as any, options.initialValues)
    errors.value = {}
  }

  return {
    values,
    errors,
    loading,
    isValidating,
    submit,
    validate,
    reset
  }
}
