'use client';

import { useQuery } from '@tanstack/react-query';
import { AlertCircle, Inbox } from 'lucide-react';

import { Alert, AlertDescription, AlertTitle } from '@/components/ui/alert';
import { Button } from '@/components/ui/button';
import { featureApi } from '@/lib/api/features';

import { FeatureCard } from './feature-card';
import { FeatureListSkeleton } from './feature-list-skeleton';

export function FeatureList() {
  const {
    data,
    isLoading,
    isError,
    error,
    refetch,
  } = useQuery({
    queryKey: ['features'],
    queryFn: () => featureApi.getAll(),
  });

  // Loading state
  if (isLoading) {
    return <FeatureListSkeleton />;
  }

  // Error state
  if (isError) {
    return (
      <Alert variant="destructive">
        <AlertCircle className="h-4 w-4" />
        <AlertTitle>Error loading features</AlertTitle>
        <AlertDescription className="flex items-center gap-4">
          <span>{error?.message || 'Something went wrong'}</span>
          <Button variant="outline" size="sm" onClick={() => refetch()}>
            Try again
          </Button>
        </AlertDescription>
      </Alert>
    );
  }

  // Empty state
  if (!data?.data?.length) {
    return (
      <div className="flex flex-col items-center justify-center py-12 text-center">
        <Inbox className="h-12 w-12 text-muted-foreground mb-4" />
        <h3 className="text-lg font-medium">No features yet</h3>
        <p className="text-sm text-muted-foreground mb-4">
          Get started by creating your first feature.
        </p>
        <Button>Create Feature</Button>
      </div>
    );
  }

  // Success state
  return (
    <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-3">
      {data.data.map((feature) => (
        <FeatureCard key={feature.id} feature={feature} />
      ))}
    </div>
  );
}
