'use client';

import { Plus } from 'lucide-react';
import Link from 'next/link';

import { Button } from '@/components/ui/button';

export function FeatureHeader() {
  return (
    <div className="flex items-center justify-between mb-8">
      <div>
        <h1 className="text-3xl font-bold tracking-tight">Features</h1>
        <p className="text-muted-foreground">
          Manage and organize your features
        </p>
      </div>

      <Button asChild>
        <Link href="/features/new">
          <Plus className="mr-2 h-4 w-4" />
          New Feature
        </Link>
      </Button>
    </div>
  );
}
