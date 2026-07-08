import { useLiveNavigation } from "live_vue";

type QueryValue = string | number | boolean | null | undefined;

type PatchQueryOptions = {
  path?: string;
  replace?: boolean;
};

export function useRouteQueryPatch() {
  const { patch } = useLiveNavigation();

  const patchQuery = (
    updates: Record<string, QueryValue>,
    options: PatchQueryOptions = {},
  ) => {
    const url = new URL(window.location.href);
    const path = options.path || url.pathname;

    Object.entries(updates).forEach(([key, value]) => {
      if (value === null || value === undefined || value === "") {
        url.searchParams.delete(key);
        return;
      }

      url.searchParams.set(key, String(value));
    });

    const query = url.searchParams.toString();
    const href = query === "" ? path : `${path}?${query}`;

    patch(href, { replace: options.replace ?? true });
  };

  return { patchQuery };
}
