// Validate preview metadata before the host initializes clocks or source links.
export function validateCatalog(assets) {
  const ids = new Set();
  for (const asset of assets) {
    for (const field of ['id', 'name', 'family', 'familyName', 'description', 'motion']) {
      if (typeof asset[field] !== 'string' || !asset[field].trim()) throw new TypeError(`Asset ${asset.id ?? '?'} needs ${field}`);
    }
    if (!/^[a-z0-9-]+$/.test(asset.id) || !/^[a-z0-9-]+$/.test(asset.family)) throw new TypeError('Asset source identifiers must be URL-safe');
    if (ids.has(asset.id)) throw new TypeError(`Duplicate asset ${asset.id}`);
    ids.add(asset.id);
    if (!Number.isInteger(asset.number) || asset.number < 1) throw new TypeError(`Invalid number for ${asset.id}`);
    if (!Number.isFinite(asset.duration) || asset.duration <= 0) throw new TypeError(`Invalid duration for ${asset.id}`);
    if (!Number.isFinite(asset.previewAt) || asset.previewAt < 0 || asset.previewAt > 1) throw new TypeError(`Invalid previewAt for ${asset.id}`);
    if (!Array.isArray(asset.supports) || typeof asset.draw !== 'function') throw new TypeError(`Invalid renderer contract for ${asset.id}`);
  }
  return assets;
}
