import { readdirSync, statSync } from "node:fs";
import { join, resolve } from "node:path";
import { execFileSync } from "node:child_process";

function collectJsFiles(directory) {
  const entries = readdirSync(directory);
  const files = [];

  for (const entry of entries) {
    const fullPath = join(directory, entry);
    const stat = statSync(fullPath);
    if (stat.isDirectory()) {
      files.push(...collectJsFiles(fullPath));
      continue;
    }
    if (fullPath.endsWith(".js")) {
      files.push(fullPath);
    }
  }

  return files;
}

const root = resolve(process.cwd(), "..");
const targets = [
  resolve(process.cwd(), "src"),
  resolve(root, "supabase", "functions")
];

for (const target of targets) {
  for (const file of collectJsFiles(target)) {
    execFileSync(process.execPath, ["--check", file], { stdio: "inherit" });
  }
}
