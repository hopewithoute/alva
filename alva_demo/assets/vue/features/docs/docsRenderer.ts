import MarkdownIt from "markdown-it";
import { createHighlighter, type Highlighter } from "shiki";

let highlighterPromise: Promise<Highlighter> | null = null;

function getHighlighterInstance(): Promise<Highlighter> {
  if (!highlighterPromise) {
    highlighterPromise = createHighlighter({
      themes: ["github-light", "github-dark"],
      langs: ["elixir", "typescript", "vue", "bash", "json", "html", "css"]
    });
  }
  return highlighterPromise;
}

export function getActiveShikiTheme(): "github-dark" | "github-light" {
  if (typeof document !== "undefined" && document.documentElement.classList.contains("dark")) {
    return "github-dark";
  }
  return "github-light";
}

const md = new MarkdownIt({
  html: true,
  linkify: true,
  typographer: true
});

export async function renderMarkdownToHtml(
  markdown: string,
  customTheme?: string
): Promise<string> {
  try {
    const highlighter = await getHighlighterInstance();
    const activeTheme = customTheme || getActiveShikiTheme();

    const customMd = new MarkdownIt({
      html: true,
      linkify: true,
      typographer: true,
      highlight: (code, lang) => {
        const validLang =
          lang &&
          ["elixir", "typescript", "ts", "vue", "bash", "sh", "json", "html", "css"].includes(lang)
            ? lang === "ts"
              ? "typescript"
              : lang === "sh"
                ? "bash"
                : lang
            : "text";

        try {
          return highlighter.codeToHtml(code, {
            lang: validLang,
            theme: activeTheme
          });
        } catch {
          return md.utils.escapeHtml(code);
        }
      }
    });

    return customMd.render(markdown);
  } catch (err) {
    console.error("Failed to initialize Shiki highlighter, falling back to basic rendering", err);
    return md.render(markdown);
  }
}

export async function highlightCode(
  code: string,
  lang: string,
  customTheme?: string
): Promise<string> {
  try {
    const highlighter = await getHighlighterInstance();
    const activeTheme = customTheme || getActiveShikiTheme();
    const validLang =
      lang &&
      ["elixir", "typescript", "ts", "vue", "bash", "sh", "json", "html", "css"].includes(lang)
        ? lang === "ts"
          ? "typescript"
          : lang === "sh"
            ? "bash"
            : lang
        : "text";
    return highlighter.codeToHtml(code, {
      lang: validLang,
      theme: activeTheme
    });
  } catch {
    return `<pre><code>${md.utils.escapeHtml(code)}</code></pre>`;
  }
}
