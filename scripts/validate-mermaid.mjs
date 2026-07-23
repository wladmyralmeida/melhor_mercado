import fs from 'node:fs';
import { JSDOM } from 'jsdom';

const dom = new JSDOM('<!doctype html><html><body></body></html>');
globalThis.window = dom.window;
globalThis.document = dom.window.document;
Object.defineProperty(globalThis, 'navigator', { value: dom.window.navigator, configurable: true });
globalThis.Element = dom.window.Element;
globalThis.HTMLElement = dom.window.HTMLElement;
globalThis.Node = dom.window.Node;
globalThis.DocumentFragment = dom.window.DocumentFragment;
globalThis.NodeFilter = dom.window.NodeFilter;
globalThis.SVGElement = dom.window.SVGElement;

const mermaid = (await import('mermaid')).default;
mermaid.initialize({ startOnLoad: false, securityLevel: 'loose' });

const doc = fs.readFileSync(process.argv[2], 'utf8');
const blocks = [...doc.matchAll(/```mermaid\n([\s\S]*?)```/g)].map(m => m[1]);
console.log(`Encontrados ${blocks.length} blocos mermaid em ${process.argv[2].split('/').pop()}`);
let fail = 0;
for (const [i, code] of blocks.entries()) {
  const kind = code.trim().split('\n')[0].slice(0, 45);
  try {
    await mermaid.parse(code);
    console.log(`  [OK]    #${i + 1}  ${kind}`);
  } catch (e) {
    fail++;
    console.log(`  [ERRO]  #${i + 1}  ${kind}`);
    console.log('          ' + String(e.message || e).split('\n').slice(0, 8).join('\n          '));
  }
}
console.log(fail ? `\n${fail} diagrama(s) invalido(s)` : '\nTodos os diagramas sao sintaticamente validos');
process.exit(fail ? 1 : 0);

// Uso:  npx --yes -p mermaid@11 -p jsdom node scripts/validate-mermaid.mjs docs/*.md
// Gate de CI: falha se qualquer bloco ```mermaid``` do repositorio nao parsear.
