import * as esbuild from "esbuild";

await esbuild.build({
  entryPoints: ["main.ts"],
  bundle: true,
  platform: "node",
  format: "esm",
  outfile: "../dist/main.js",
  banner: {
    js: "import{createRequire}from'module';const require=createRequire(import.meta.url);",
  },
});
