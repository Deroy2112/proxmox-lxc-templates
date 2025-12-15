/**
 * Category definitions for template organization.
 * Used across sidebar, index, and template detail pages.
 */

export interface Category {
  name: string;
  label: string;
  icon: string;
  count: number;
}

/**
 * Default category list - counts are calculated at runtime.
 */
export const defaultCategories: Category[] = [
  { name: "media", label: "Media & Indexer", icon: "film", count: 0 },
  { name: "network", label: "Network & Proxy", icon: "globe", count: 0 },
  { name: "database", label: "Database", icon: "database", count: 0 },
  { name: "automation", label: "Automation", icon: "zap", count: 0 },
  { name: "monitoring", label: "Monitoring", icon: "chart", count: 0 },
  { name: "storage", label: "Storage & Files", icon: "folder", count: 0 },
  { name: "security", label: "Security", icon: "shield", count: 0 },
  { name: "development", label: "Development", icon: "code", count: 0 },
];

/**
 * Get a fresh copy of categories with reset counts.
 */
export function getCategories(): Category[] {
  return defaultCategories.map((cat) => ({ ...cat, count: 0 }));
}
