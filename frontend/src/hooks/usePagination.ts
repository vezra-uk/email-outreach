import { useState, useCallback } from 'react';

export interface PaginationState {
  page: number;
  per_page: number;
}

export interface PaginatedData<T> {
  items: T[];
  total: number;
  page: number;
  per_page: number;
  total_pages: number;
  has_next: boolean;
  has_prev: boolean;
}

export interface UsePaginationOptions {
  initialPage?: number;
  initialPerPage?: number;
  onPageChange?: (page: number) => void;
}

export function usePagination(options: UsePaginationOptions = {}) {
  const {
    initialPage = 1,
    initialPerPage = 20,
    onPageChange
  } = options;

  const [pagination, setPagination] = useState<PaginationState>({
    page: initialPage,
    per_page: initialPerPage
  });

  const goToPage = useCallback((page: number) => {
    setPagination(prev => ({ ...prev, page }));
    onPageChange?.(page);
  }, [onPageChange]);

  const nextPage = useCallback(() => {
    setPagination(prev => ({ ...prev, page: prev.page + 1 }));
  }, []);

  const prevPage = useCallback(() => {
    setPagination(prev => ({ ...prev, page: Math.max(1, prev.page - 1) }));
  }, []);

  const setPerPage = useCallback((per_page: number) => {
    setPagination(prev => ({ ...prev, per_page, page: 1 })); // Reset to first page when changing per_page
  }, []);

  const reset = useCallback(() => {
    setPagination({ page: initialPage, per_page: initialPerPage });
  }, [initialPage, initialPerPage]);

  // Helper to build query params for API calls
  const getQueryParams = useCallback(() => {
    return new URLSearchParams({
      page: pagination.page.toString(),
      per_page: pagination.per_page.toString()
    });
  }, [pagination]);

  return {
    pagination,
    goToPage,
    nextPage,
    prevPage,
    setPerPage,
    reset,
    getQueryParams
  };
}