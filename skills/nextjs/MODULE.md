# Next.js Skill Module

> Frontend development with Next.js 15 App Router for Kuark projects

## Triggers

- page, component, App Router
- Server Component, Client Component
- form, Zustand, TanStack Query
- "sayfa oluştur", "component yaz", "form ekle"

## Technology Stack

- Next.js 15+ (App Router)
- TypeScript strict mode
- Tailwind CSS
- shadcn/ui components
- TanStack Query (server state)
- Zustand (client state)
- React Hook Form + Zod
- nuqs (URL state)

## Directory Structure

```
app/
├── (auth)/
│   ├── login/
│   │   └── page.tsx
│   ├── register/
│   │   └── page.tsx
│   └── layout.tsx
├── (dashboard)/
│   ├── layout.tsx
│   ├── page.tsx
│   └── [feature]/
│       ├── page.tsx
│       ├── [id]/
│       │   └── page.tsx
│       └── new/
│           └── page.tsx
├── api/
│   └── [...proxy]/
│       └── route.ts
├── layout.tsx
└── globals.css

components/
├── ui/                  # shadcn/ui components
├── [feature]/           # Feature-specific components
│   ├── feature-list.tsx
│   ├── feature-form.tsx
│   └── feature-card.tsx
└── shared/              # Shared components
    ├── data-table.tsx
    ├── error-display.tsx
    └── empty-state.tsx

lib/
├── api/
│   └── client.ts        # API client
├── hooks/
│   └── use-feature.ts   # Feature hooks
├── stores/
│   └── feature-store.ts # Zustand stores
└── utils/
    └── cn.ts            # Utility functions
```

## Core Patterns

### Server Component (Default)
```typescript
// app/features/page.tsx
import { getFeatures } from '@/lib/api';
import { FeatureList } from '@/components/features/feature-list';

export default async function FeaturesPage() {
  const features = await getFeatures();

  return (
    <div className="container py-6">
      <div className="flex justify-between items-center mb-6">
        <h1 className="text-2xl font-bold">Features</h1>
        <Link href="/features/new">
          <Button>Add Feature</Button>
        </Link>
      </div>
      <FeatureList features={features} />
    </div>
  );
}
```

### Client Component with TanStack Query
```typescript
'use client';

import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { getFeatures, createFeature, deleteFeature } from '@/lib/api';
import { Skeleton } from '@/components/ui/skeleton';
import { ErrorDisplay } from '@/components/shared/error-display';
import { EmptyState } from '@/components/shared/empty-state';

export function FeatureList() {
  const queryClient = useQueryClient();

  const { data, isLoading, error, refetch } = useQuery({
    queryKey: ['features'],
    queryFn: getFeatures,
  });

  const deleteMutation = useMutation({
    mutationFn: deleteFeature,
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['features'] });
    },
  });

  // ALL states required:
  if (isLoading) return <FeatureListSkeleton />;
  if (error) return <ErrorDisplay error={error} onRetry={refetch} />;
  if (!data?.length) return <EmptyState onCreate={() => router.push('/features/new')} />;

  return (
    <div className="space-y-4">
      {data.map((feature) => (
        <FeatureCard
          key={feature.id}
          feature={feature}
          onDelete={() => deleteMutation.mutate(feature.id)}
        />
      ))}
    </div>
  );
}
```

### Form with React Hook Form + Zod
```typescript
'use client';

import { useForm } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import { z } from 'zod';
import { useMutation, useQueryClient } from '@tanstack/react-query';
import { createFeature } from '@/lib/api';
import { useRouter } from 'next/navigation';
import { toast } from 'sonner';
import {
  Form,
  FormControl,
  FormField,
  FormItem,
  FormLabel,
  FormMessage,
} from '@/components/ui/form';
import { Input } from '@/components/ui/input';
import { Button } from '@/components/ui/button';

const formSchema = z.object({
  name: z.string().min(2, 'Name must be at least 2 characters'),
  description: z.string().optional(),
  status: z.enum(['ACTIVE', 'INACTIVE']).default('ACTIVE'),
});

type FormValues = z.infer<typeof formSchema>;

export function FeatureForm() {
  const router = useRouter();
  const queryClient = useQueryClient();

  const form = useForm<FormValues>({
    resolver: zodResolver(formSchema),
    defaultValues: {
      name: '',
      description: '',
      status: 'ACTIVE',
    },
  });

  const mutation = useMutation({
    mutationFn: createFeature,
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['features'] });
      toast.success('Feature created successfully');
      router.push('/features');
    },
    onError: (error) => {
      toast.error(error.message || 'Failed to create feature');
    },
  });

  const onSubmit = (values: FormValues) => {
    mutation.mutate(values);
  };

  return (
    <Form {...form}>
      <form onSubmit={form.handleSubmit(onSubmit)} className="space-y-6">
        <FormField
          control={form.control}
          name="name"
          render={({ field }) => (
            <FormItem>
              <FormLabel>Name</FormLabel>
              <FormControl>
                <Input placeholder="Feature name" {...field} />
              </FormControl>
              <FormMessage />
            </FormItem>
          )}
        />

        <FormField
          control={form.control}
          name="description"
          render={({ field }) => (
            <FormItem>
              <FormLabel>Description</FormLabel>
              <FormControl>
                <Textarea placeholder="Description" {...field} />
              </FormControl>
              <FormMessage />
            </FormItem>
          )}
        />

        <div className="flex gap-4">
          <Button type="button" variant="outline" onClick={() => router.back()}>
            Cancel
          </Button>
          <Button type="submit" disabled={mutation.isPending}>
            {mutation.isPending ? 'Creating...' : 'Create Feature'}
          </Button>
        </div>
      </form>
    </Form>
  );
}
```

### Zustand Store
```typescript
// lib/stores/feature-store.ts
import { create } from 'zustand';

interface FeatureState {
  selectedFeature: Feature | null;
  isFormOpen: boolean;
  setSelectedFeature: (feature: Feature | null) => void;
  openForm: () => void;
  closeForm: () => void;
}

export const useFeatureStore = create<FeatureState>((set) => ({
  selectedFeature: null,
  isFormOpen: false,
  setSelectedFeature: (feature) => set({ selectedFeature: feature }),
  openForm: () => set({ isFormOpen: true }),
  closeForm: () => set({ isFormOpen: false, selectedFeature: null }),
}));
```

### API Client
```typescript
// lib/api/client.ts
const API_URL = process.env.NEXT_PUBLIC_API_URL || 'http://localhost:3001';

async function fetchApi<T>(
  endpoint: string,
  options: RequestInit = {}
): Promise<T> {
  const token = typeof window !== 'undefined'
    ? localStorage.getItem('token')
    : null;

  const res = await fetch(`${API_URL}${endpoint}`, {
    ...options,
    headers: {
      'Content-Type': 'application/json',
      ...(token && { Authorization: `Bearer ${token}` }),
      ...options.headers,
    },
  });

  if (!res.ok) {
    const error = await res.json().catch(() => ({}));
    throw new Error(error.message || 'API request failed');
  }

  return res.json();
}

// Feature API
export const getFeatures = () =>
  fetchApi<FeatureListResponse>('/features');

export const getFeature = (id: string) =>
  fetchApi<Feature>(`/features/${id}`);

export const createFeature = (data: CreateFeatureInput) =>
  fetchApi<Feature>('/features', {
    method: 'POST',
    body: JSON.stringify(data),
  });

export const updateFeature = (id: string, data: UpdateFeatureInput) =>
  fetchApi<Feature>(`/features/${id}`, {
    method: 'PUT',
    body: JSON.stringify(data),
  });

export const deleteFeature = (id: string) =>
  fetchApi<void>(`/features/${id}`, { method: 'DELETE' });
```

## State Management Rules

| Data Type | Solution |
|-----------|----------|
| Server data | TanStack Query (useQuery/useMutation) |
| Global UI state | Zustand |
| Local UI state | useState/useReducer |
| Form state | React Hook Form + Zod |
| URL state | nuqs or useSearchParams |

## Required State Handling

Every component that fetches data MUST handle:
1. **Loading state** - Show skeleton/spinner
2. **Error state** - Show error with retry option
3. **Empty state** - Show empty state with action
4. **Success state** - Show the data

```typescript
if (isLoading) return <Skeleton />;
if (error) return <ErrorDisplay onRetry={refetch} />;
if (!data?.length) return <EmptyState onCreate={handleCreate} />;
return <DataView data={data} />;
```

## Component Patterns

### Shared Components
```typescript
// components/shared/error-display.tsx
'use client';

import { AlertCircle } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { Alert, AlertDescription, AlertTitle } from '@/components/ui/alert';

interface ErrorDisplayProps {
  error?: Error | null;
  onRetry?: () => void;
}

export function ErrorDisplay({ error, onRetry }: ErrorDisplayProps) {
  return (
    <Alert variant="destructive">
      <AlertCircle className="h-4 w-4" />
      <AlertTitle>Error</AlertTitle>
      <AlertDescription>
        {error?.message || 'Something went wrong'}
      </AlertDescription>
      {onRetry && (
        <Button variant="outline" size="sm" onClick={onRetry} className="mt-2">
          Try Again
        </Button>
      )}
    </Alert>
  );
}

// components/shared/empty-state.tsx
'use client';

import { Plus } from 'lucide-react';
import { Button } from '@/components/ui/button';

interface EmptyStateProps {
  title?: string;
  description?: string;
  onCreate?: () => void;
}

export function EmptyState({
  title = 'No items found',
  description = 'Get started by creating a new item',
  onCreate
}: EmptyStateProps) {
  return (
    <div className="flex flex-col items-center justify-center py-12 text-center">
      <h3 className="text-lg font-semibold">{title}</h3>
      <p className="text-sm text-muted-foreground mt-1">{description}</p>
      {onCreate && (
        <Button onClick={onCreate} className="mt-4">
          <Plus className="h-4 w-4 mr-2" />
          Create New
        </Button>
      )}
    </div>
  );
}
```

## Validation Checklist

- [ ] Server/Client component decision correct
- [ ] All 4 states handled (loading, error, empty, success)
- [ ] TanStack Query for server data
- [ ] Zustand for global UI state
- [ ] React Hook Form + Zod for forms
- [ ] Proper TypeScript types
- [ ] Responsive design (Tailwind)
- [ ] Accessibility (shadcn/ui)
