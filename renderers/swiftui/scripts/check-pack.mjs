#!/usr/bin/env node
// Consistency check for this renderer pack (no dependencies): the orbRenderer
// manifest is well-formed, its declared dirs exist, every per-pattern source is a
// covered pattern, and no renderer is a 🔧 placeholder.
import fs from 'node:fs';
import path from 'node:path';

const root = path.resolve(path.dirname(new URL(import.meta.url).pathname), '..');
const manifest = JSON.parse(fs.readFileSync(path.join(root, 'package.json'), 'utf8'));
const block = manifest.orbRenderer;
const problems = [];
if (!block) problems.push('package.json has no orbRenderer block');
else {
  if (block.target !== 'ios') problems.push(`orbRenderer.target is ${block.target}, expected ios`);
  if (!Number.isInteger(block.rendererInterface)) problems.push('orbRenderer.rendererInterface is not an integer');
  if (!Array.isArray(block.coverage) || block.coverage.length === 0) problems.push('orbRenderer.coverage is empty');
  for (const key of ['sources', 'fixtures', 'patternsRegistry']) if (!block[key]) problems.push(`orbRenderer.${key} missing`);
  const sources = path.join(root, block.sources ?? '');
  const covered = new Set(block.coverage ?? []);
  for (const tier of ['atoms', 'molecules', 'organisms', 'templates']) {
    const dir = path.join(sources, tier);
    if (!fs.existsSync(dir)) continue;
    for (const file of fs.readdirSync(dir).filter((f) => f.endsWith('.swift'))) {
      const pattern = file.slice(0, -'.swift'.length).replaceAll('_', '-');
      if (!covered.has(pattern)) problems.push(`${tier}/${file} is not in orbRenderer.coverage`);
      if (fs.readFileSync(path.join(dir, file), 'utf8').includes('\u{1f527}')) problems.push(`${tier}/${file} is a 🔧 placeholder`);
    }
  }
  if (!fs.existsSync(path.join(root, block.fixtures ?? ''))) problems.push(`fixtures dir ${block.fixtures} missing`);
}
if (problems.length > 0) {
  console.error(`renderer pack check failed (${problems.length}):\n  ${problems.join('\n  ')}`);
  process.exit(1);
}
console.log(`renderer pack ok: ${block.target}, interface ${block.rendererInterface}, ${block.coverage.length} patterns`);
