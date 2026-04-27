#!/usr/bin/env npx tsx
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import * as p from "@clack/prompts";

const repoDir = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const agentDir = path.join(process.env.HOME || process.env.USERPROFILE || "", ".pi/agent");

interface Item {
  id: string;
  label: string;
  src: string;
  dst: string;
}

function scan(from: string, to: string, prefix: string): Item[] {
  if (!fs.existsSync(from)) return [];
  return fs.readdirSync(from)
    .filter((n) => !n.startsWith("."))
    .sort()
    .map((name) => ({
      id: `${prefix}:${name}`,
      label: `[${prefix}] ${name}`,
      src: path.join(from, name),
      dst: path.join(to, name),
    }));
}

const items = [
  ...scan(path.join(repoDir, "skills"), path.join(agentDir, "skills"), "skill"),
  ...scan(path.join(repoDir, "extensions"), path.join(agentDir, "extensions"), "ext"),
];

if (!items.length) {
  p.cancel("Nothing to install.");
  process.exit(1);
}

p.intro("a2-po-tools installer");

const selected = await p.multiselect({
  message: "Select items to install",
  options: items.map((i) => ({ value: i.id, label: i.label })),
});

if (p.isCancel(selected) || !selected?.length) {
  p.cancel(selected ? "Nothing selected." : "Aborted.");
  process.exit(0);
}

const s = p.spinner();
s.start("Installing...");

for (const id of selected) {
  const item = items.find((i) => i.id === id)!;
  fs.mkdirSync(path.dirname(item.dst), { recursive: true });
  fs.cpSync(item.src, item.dst, { recursive: true, force: true });
}

s.stop(`Installed ${selected.length} item(s). Restart pi to pick them up.`);
p.outro("Done.");
