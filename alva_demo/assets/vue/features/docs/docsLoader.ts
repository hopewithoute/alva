export interface GuideMeta {
  slug: string;
  filename: string;
  order: number;
  title: string;
  description: string;
  category: string;
  rawContent: string;
}

const guideModules = import.meta.glob('../../../../../alva/guides/*.md', {
  query: '?raw',
  import: 'default',
  eager: true
}) as Record<string, string>;

const slugMap: Record<string, { slug: string; title: string; category: string; description: string }> = {
  '01-getting-started.md': {
    slug: 'getting-started',
    title: 'Getting Started',
    category: 'Overview',
    description: 'Installation, configuration, and foundational setup for Alva.'
  },
  '02-ash-backend-setup.md': {
    slug: 'ash-backend-setup',
    title: 'Ash Backend Setup',
    category: 'Backend Architecture',
    description: 'Configuring Alva.Resource and Alva.Domain DSL extensions.'
  },
  '03-liveview-integration.md': {
    slug: 'liveview-integration',
    title: 'LiveView Integration',
    category: 'Backend Architecture',
    description: 'Mounting Alva.LiveView streams, uploads, and route lifecycle reconfiguration.'
  },
  '04-queries-and-actions.md': {
    slug: 'queries-and-actions',
    title: 'Queries & Direct Actions',
    category: 'Frontend Composables',
    description: 'Reactive data fetching with useAlvaQuery and direct event execution with useAlvaApi.'
  },
  '05-forms-and-mutations.md': {
    slug: 'forms-and-mutations',
    title: 'Forms & Mutations',
    category: 'Frontend Composables',
    description: 'Stateful forms with debounced server validation and Ash changeset error mapping.'
  },
  '06-frontend-composables.md': {
    slug: 'frontend-composables',
    title: 'Frontend Composables Reference',
    category: 'Frontend Composables',
    description: 'Unified API reference for useAlvaQuery, useAlvaForm, use_signal_state, and use_action_upload.'
  },
  '07-uploads.md': {
    slug: 'uploads',
    title: 'LiveView Uploads',
    category: 'Advanced Integrations',
    description: 'Managing file progress, previews, and Ash file argument references.'
  },
  '08-streams.md': {
    slug: 'streams',
    title: 'Real-Time Streams',
    category: 'Advanced Integrations',
    description: 'Zero-memory collection streaming, dynamic scope assigns, and automatic mutation synchronization.'
  },
  '09-signals.md': {
    slug: 'signals',
    title: 'Real-Time Signals',
    category: 'Realtime & PubSub',
    description: 'Subscribing to Phoenix PubSub topics and authorized signal broadcasts.'
  }
};

export function getAllGuides(): GuideMeta[] {
  const guides: GuideMeta[] = [];

  for (const [filepath, content] of Object.entries(guideModules)) {
    const filename = filepath.split('/').pop() || '';
    const meta = slugMap[filename];
    if (!meta) continue;

    const orderMatch = filename.match(/^(\d+)-/);
    const order = orderMatch ? parseInt(orderMatch[1], 10) : 99;

    guides.push({
      slug: meta.slug,
      filename,
      order,
      title: meta.title,
      description: meta.description,
      category: meta.category,
      rawContent: content
    });
  }

  return guides.sort((a, b) => a.order - b.order);
}

export function getGuideBySlug(slug: string): GuideMeta | undefined {
  const guides = getAllGuides();
  return guides.find((g) => g.slug === slug);
}
