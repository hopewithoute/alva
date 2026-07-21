import MarkdownIt from 'markdown-it';
import { createHighlighter, type Highlighter } from 'shiki';

let highlighterPromise: Promise<Highlighter> | null = null;

function getHighlighterInstance(): Promise<Highlighter> {
  if (!highlighterPromise) {
    highlighterPromise = createHighlighter({
      themes: ['github-dark', 'one-dark-pro'],
      langs: ['elixir', 'typescript', 'vue', 'bash', 'json', 'html', 'css']
    });
  }
  return highlighterPromise;
}

const md = new MarkdownIt({
  html: true,
  linkify: true,
  typographer: true
});

export async function renderMarkdownToHtml(markdown: string): Promise<string> {
  try {
    const highlighter = await getHighlighterInstance();

    const customMd = new MarkdownIt({
      html: true,
      linkify: true,
      typographer: true,
      highlight: (code, lang) => {
        const validLang = lang && ['elixir', 'typescript', 'ts', 'vue', 'bash', 'sh', 'json', 'html', 'css'].includes(lang)
          ? (lang === 'ts' ? 'typescript' : lang === 'sh' ? 'bash' : lang)
          : 'text';
        
        try {
          return highlighter.codeToHtml(code, {
            lang: validLang,
            theme: 'github-dark'
          });
        } catch {
          return md.utils.escapeHtml(code);
        }
      }
    });

    return customMd.render(markdown);
  } catch (err) {
    console.error('Failed to initialize Shiki highlighter, falling back to basic rendering', err);
    return md.render(markdown);
  }
}
