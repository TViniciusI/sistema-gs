import { createSeed, type DemoState } from "./seed";

const globalForDemo = globalThis as unknown as { __gsDemo?: DemoState };

export function getDemo(): DemoState {
  if (!globalForDemo.__gsDemo) {
    globalForDemo.__gsDemo = createSeed();
  }
  return globalForDemo.__gsDemo;
}

export function resetDemo() {
  globalForDemo.__gsDemo = createSeed();
}
