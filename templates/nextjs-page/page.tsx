import { Metadata } from 'next';
import { Suspense } from 'react';

import { FeatureList } from './components/feature-list';
import { FeatureListSkeleton } from './components/feature-list-skeleton';
import { FeatureHeader } from './components/feature-header';

export const metadata: Metadata = {
  title: 'Features',
  description: 'Manage your features',
};

// Server Component - data fetching
export default async function FeaturesPage() {
  return (
    <div className="container mx-auto px-4 py-8">
      <FeatureHeader />

      <Suspense fallback={<FeatureListSkeleton />}>
        <FeatureList />
      </Suspense>
    </div>
  );
}
