import { inject, provide, toRefs, ToRefs } from 'vue'

const PageStateSymbol = Symbol('AlvaPageState')

/**
 * Provides the global page state to all descendants.
 * This should be called once at the root component (the page component mounted by LiveView).
 * 
 * @param state The reactive state object (usually `props` from `defineProps`)
 */
export function providePageState<T extends object>(state: T) {
  provide(PageStateSymbol, state)
}

/**
 * Injects the global page state provided by `providePageState`.
 * Returns the state converted to refs so it can be safely destructured.
 * 
 * @example
 * const { customerName } = usePageState<{ customerName: string }>()
 */
export function usePageState<T extends object>(): ToRefs<T> {
  const state = inject<T>(PageStateSymbol)
  
  if (!state) {
    throw new Error("usePageState() was called but no state was provided. Did you forget to call providePageState() at the root component?")
  }
  
  return toRefs(state) as ToRefs<T>
}
