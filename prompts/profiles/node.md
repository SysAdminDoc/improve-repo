Stack: Node.js / JavaScript / TypeScript.

Prioritize:
- TypeScript over plain JS (incremental migration is acceptable)
- `pnpm` over `npm`/`yarn` for speed and disk efficiency
- Biome or eslint+prettier (Biome is the modern consolidated tool)
- ESM over CommonJS; `"type": "module"` in `package.json`; top-level await
- Node LTS targets (20, 22); drop EOL versions
- Strict `tsconfig.json`: `strict`, `noUncheckedIndexedAccess`, `exactOptionalPropertyTypes`
- Zod or valibot for runtime validation at boundaries
- Vitest over Jest for speed; or Node's built-in test runner
- Error propagation: no unhandled rejections; structured `AggregateError` for parallel ops
- Dependency hygiene: `npm audit --omit=dev`, `npm outdated`, automated dependabot PRs
- Build tools: Vite for apps, tsup for libraries, esbuild for scripts
- No `node-gyp` dependencies unless absolutely required (cross-platform pain)
- Package.json: `engines`, `files`, `exports`, `types` all correctly populated

Skip generic "add tests" — identify what's specifically missing in this project.
