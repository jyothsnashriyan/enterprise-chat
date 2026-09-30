import { copyFile, mkdir } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const scriptDir = path.dirname(fileURLToPath(import.meta.url));
const projectDir = path.resolve(scriptDir, '..');
const source = path.join(projectDir, 'node_modules', 'pdfjs-dist', 'build', 'pdf.worker.min.mjs');
const destination = path.join(projectDir, 'public', 'pdf.worker.min.mjs');

await mkdir(path.dirname(destination), { recursive: true });
await copyFile(source, destination);
console.log('Synced PDF.js worker to public/pdf.worker.min.mjs');
